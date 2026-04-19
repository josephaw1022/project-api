package project

import (
	"context"
	"log"
	"time"

	projectv1 "project-api/pkg/apis/project/v1"

	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/internalversion"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apiserver/pkg/authorization/authorizer"
	"k8s.io/apiserver/pkg/endpoints/request"
	"k8s.io/apiserver/pkg/registry/rest"
	"k8s.io/client-go/kubernetes"
)

var _ rest.Lister = &ProjectStorage{}
var _ rest.Getter = &ProjectStorage{}
var _ rest.Creater = &ProjectStorage{}
var _ rest.Scoper = &ProjectStorage{}
var _ rest.SingularNameProvider = &ProjectStorage{}

type ProjectStorage struct {
	client     kubernetes.Interface
	authorizer authorizer.Authorizer
}

func NewProjectStorage(client kubernetes.Interface, auth authorizer.Authorizer) *ProjectStorage {
	return &ProjectStorage{
		client:     client,
		authorizer: auth,
	}
}

func (s *ProjectStorage) New() runtime.Object {
	return &projectv1.Project{}
}

func (s *ProjectStorage) NewList() runtime.Object {
	return &projectv1.ProjectList{}
}

func (s *ProjectStorage) NamespaceScoped() bool {
	return false
}

func (s *ProjectStorage) GetSingularName() string {
	return "project"
}

func (s *ProjectStorage) Get(ctx context.Context, name string, options *metav1.GetOptions) (runtime.Object, error) {
	if err := s.authorize(ctx, name, "get"); err != nil {
		return nil, err
	}

	ns, err := s.client.CoreV1().Namespaces().Get(ctx, name, *options)
	if err != nil {
		return nil, err
	}
	return namespaceToProject(ns), nil
}

func (s *ProjectStorage) List(ctx context.Context, options *internalversion.ListOptions) (runtime.Object, error) {
	v1Options := metav1.ListOptions{}
	if options != nil {
		if options.LabelSelector != nil {
			v1Options.LabelSelector = options.LabelSelector.String()
		}
		if options.FieldSelector != nil {
			v1Options.FieldSelector = options.FieldSelector.String()
		}
		v1Options.Limit = options.Limit
		v1Options.Continue = options.Continue
	}

	nsList, err := s.client.CoreV1().Namespaces().List(ctx, v1Options)
	if err != nil {
		return nil, err
	}

	projectList := &projectv1.ProjectList{
		TypeMeta: metav1.TypeMeta{
			Kind:       "ProjectList",
			APIVersion: "project.io/v1",
		},
		ListMeta: nsList.ListMeta,
	}

	for _, ns := range nsList.Items {
		if err := s.authorize(ctx, ns.Name, "get"); err == nil {
			projectList.Items = append(projectList.Items, *namespaceToProject(&ns))
		}
	}
	return projectList, nil
}

func (s *ProjectStorage) authorize(ctx context.Context, namespace, verb string) error {
	user, ok := request.UserFrom(ctx)
	if !ok {
		return errors.NewForbidden(schema.GroupResource{Group: projectv1.GroupName, Resource: "projects"}, namespace, nil)
	}

	attrs := authorizer.AttributesRecord{
		User:            user,
		Verb:            verb,
		Namespace:       namespace,
		Resource:        "namespaces",
		ResourceRequest: true,
	}

	decision, _, err := s.authorizer.Authorize(ctx, attrs)
	if err != nil {
		return err
	}
	if decision != authorizer.DecisionAllow {
		return errors.NewForbidden(schema.GroupResource{Group: projectv1.GroupName, Resource: "projects"}, namespace, nil)
	}
	return nil
}

func (s *ProjectStorage) ConvertToTable(ctx context.Context, object runtime.Object, tableOptions runtime.Object) (*metav1.Table, error) {
	table := &metav1.Table{
		ColumnDefinitions: []metav1.TableColumnDefinition{
			{Name: "Name", Type: "string", Format: "name", Description: "Name of the project"},
			{Name: "Status", Type: "string", Description: "Status of the project"},
			{Name: "Age", Type: "string", Description: "Age of the project"},
		},
	}

	var projects []projectv1.Project
	if list, ok := object.(*projectv1.ProjectList); ok {
		table.ResourceVersion = list.ResourceVersion
		table.Continue = list.Continue
		projects = list.Items
	} else if obj, ok := object.(*projectv1.Project); ok {
		projects = append(projects, *obj)
	}

	for _, p := range projects {
		age := time.Since(p.CreationTimestamp.Time).Truncate(time.Second).String()
		table.Rows = append(table.Rows, metav1.TableRow{
			Cells: []interface{}{p.Name, p.Status.Phase, age},
			Object: runtime.RawExtension{Object: &p},
		})
	}

	return table, nil
}

func (s *ProjectStorage) Create(ctx context.Context, obj runtime.Object, createValidation rest.ValidateObjectFunc, options *metav1.CreateOptions) (runtime.Object, error) {
	project := obj.(*projectv1.Project)
	return createNamespaceWithRBAC(ctx, s.client, project.Name, project.Labels, project.Annotations, options)
}

func (s *ProjectStorage) Destroy() {}

type ProjectRequestStorage struct {
	client kubernetes.Interface
}

var _ rest.Creater = &ProjectRequestStorage{}
var _ rest.Scoper = &ProjectRequestStorage{}
var _ rest.SingularNameProvider = &ProjectRequestStorage{}

func NewProjectRequestStorage(client kubernetes.Interface) *ProjectRequestStorage {
	return &ProjectRequestStorage{client: client}
}

func (s *ProjectRequestStorage) New() runtime.Object {
	return &projectv1.ProjectRequest{}
}

func (s *ProjectRequestStorage) NamespaceScoped() bool {
	return false
}

func (s *ProjectRequestStorage) GetSingularName() string {
	return "projectrequest"
}

func (s *ProjectRequestStorage) Create(ctx context.Context, obj runtime.Object, createValidation rest.ValidateObjectFunc, options *metav1.CreateOptions) (runtime.Object, error) {
	pr := obj.(*projectv1.ProjectRequest)
	
	labels := map[string]string{}
	annotations := map[string]string{
		"openshift.io/display-name": pr.DisplayName,
		"openshift.io/description":  pr.Description,
	}
	
	return createNamespaceWithRBAC(ctx, s.client, pr.Name, labels, annotations, options)
}

func (s *ProjectRequestStorage) Destroy() {}

func createNamespaceWithRBAC(ctx context.Context, client kubernetes.Interface, name string, labels, annotations map[string]string, options *metav1.CreateOptions) (runtime.Object, error) {
	user, ok := request.UserFrom(ctx)
	if !ok {
		return nil, errors.NewInternalError(nil)
	}

	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name:        name,
			Labels:      labels,
			Annotations: annotations,
		},
	}
	
	newNs, err := client.CoreV1().Namespaces().Create(ctx, ns, *options)
	if err != nil {
		return nil, err
	}

	// Create RoleBinding to grant the user 'admin' permissions in their new namespace
	rb := &rbacv1.RoleBinding{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "project-admin",
			Namespace: name,
		},
		RoleRef: rbacv1.RoleRef{
			APIGroup: "rbac.authorization.k8s.io",
			Kind:     "ClusterRole",
			Name:     "admin",
		},
		Subjects: []rbacv1.Subject{
			{
				Kind:     "User",
				APIGroup: "rbac.authorization.k8s.io",
				Name:     user.GetName(),
			},
		},
	}
	
	_, err = client.RbacV1().RoleBindings(name).Create(context.Background(), rb, metav1.CreateOptions{})
	if err != nil {
		log.Printf("Warning: failed to create admin rolebinding for user %s in namespace %s: %v", user.GetName(), name, err)
	}

	return namespaceToProject(newNs), nil
}

func namespaceToProject(ns *corev1.Namespace) *projectv1.Project {
	return &projectv1.Project{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Project",
			APIVersion: "project.io/v1",
		},
		ObjectMeta: ns.ObjectMeta,
		Status: projectv1.ProjectStatus{
			Phase: string(ns.Status.Phase),
		},
	}
}
