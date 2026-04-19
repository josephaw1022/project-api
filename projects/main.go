package main

import (
	"log"
	"os"

	projectv1 "project-api/pkg/apis/project/v1"
	projectrest "project-api/pkg/registry/project"

	"github.com/spf13/pflag"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	apiserverrest "k8s.io/apiserver/pkg/registry/rest"
	genericapiserver "k8s.io/apiserver/pkg/server"
	genericoptions "k8s.io/apiserver/pkg/server/options"
	"k8s.io/client-go/kubernetes"
	clientrest "k8s.io/client-go/rest"
	basecompatibility "k8s.io/component-base/compatibility"
	openapicommon "k8s.io/kube-openapi/pkg/common"
	"k8s.io/kube-openapi/pkg/validation/spec"
)

func main() {
	scheme := runtime.NewScheme()
	projectv1.AddToScheme(scheme)

	codecs := serializer.NewCodecFactory(scheme)

	options := genericoptions.NewRecommendedOptions("", nil)
	options.SecureServing.BindPort = 443
	options.Etcd = nil
	options.Audit = nil
	options.Features = nil
	
	fs := pflag.NewFlagSet("project-api", pflag.ExitOnError)
	options.AddFlags(fs)
	fs.Parse(os.Args[1:])

	serverConfig := genericapiserver.NewRecommendedConfig(codecs)
	
	if serverConfig.EffectiveVersion == nil {
		serverConfig.EffectiveVersion = basecompatibility.NewEffectiveVersionFromString("1.34.0", "1.34.0", "1.34.0")
	}

	if err := options.ApplyTo(serverConfig); err != nil {
		log.Fatalf("Failed to apply options: %v", err)
	}

	getDefinitions := func(ref openapicommon.ReferenceCallback) map[string]openapicommon.OpenAPIDefinition {
		defs := map[string]openapicommon.OpenAPIDefinition{
			"project-api/pkg/apis/project/v1.Project": {
				Schema: spec.Schema{SchemaProps: spec.SchemaProps{Type: []string{"object"}}},
			},
			"project-api/pkg/apis/project/v1.ProjectList": {
				Schema: spec.Schema{SchemaProps: spec.SchemaProps{Type: []string{"object"}}},
			},
			"project-api/pkg/apis/project/v1.ProjectRequest": {
				Schema: spec.Schema{SchemaProps: spec.SchemaProps{Type: []string{"object"}}},
			},
			"io.k8s.apimachinery.pkg.version.Info": {
				Schema: spec.Schema{SchemaProps: spec.SchemaProps{Type: []string{"object"}}},
			},
		}
		
		commonTypes := []string{
			"io.k8s.apimachinery.pkg.apis.meta.v1.APIGroupList",
			"io.k8s.apimachinery.pkg.apis.meta.v1.APIGroup",
			"io.k8s.apimachinery.pkg.apis.meta.v1.APIResourceList",
			"io.k8s.apimachinery.pkg.apis.meta.v1.APIVersions",
			"io.k8s.apimachinery.pkg.apis.meta.v1.Status",
			"io.k8s.apimachinery.pkg.apis.meta.v1.WatchEvent",
			"io.k8s.apimachinery.pkg.apis.meta.v1.ListOptions",
			"io.k8s.apimachinery.pkg.apis.meta.v1.GetOptions",
			"io.k8s.apimachinery.pkg.apis.meta.v1.DeleteOptions",
			"io.k8s.apimachinery.pkg.apis.meta.v1.CreateOptions",
			"io.k8s.apimachinery.pkg.apis.meta.v1.UpdateOptions",
			"io.k8s.apimachinery.pkg.apis.meta.v1.PatchOptions",
		}
		for _, t := range commonTypes {
			defs[t] = openapicommon.OpenAPIDefinition{
				Schema: spec.Schema{SchemaProps: spec.SchemaProps{Type: []string{"object"}}},
			}
		}
		return defs
	}

	serverConfig.OpenAPIConfig = &openapicommon.Config{
		Info: &spec.Info{
			InfoProps: spec.InfoProps{
				Title: "Project API",
			},
		},
		GetDefinitions: getDefinitions,
	}
	serverConfig.OpenAPIV3Config = &openapicommon.OpenAPIV3Config{
		Info: &spec.Info{
			InfoProps: spec.InfoProps{
				Title: "Project API",
			},
		},
		GetDefinitions: getDefinitions,
	}

	config, err := clientrest.InClusterConfig()
	if err != nil {
		log.Fatalf("Failed to get in-cluster config: %v", err)
	}
	
	serverConfig.LoopbackClientConfig = config
	if serverConfig.ExternalAddress == "" {
		serverConfig.ExternalAddress = "project-api.project-api-system.svc"
	}
	
	kubeClient, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatalf("Failed to create kube client: %v", err)
	}

	completedConfig := serverConfig.Complete()
	server, err := completedConfig.New("project-api", genericapiserver.NewEmptyDelegate())
	if err != nil {
		log.Fatalf("Failed to create server: %v", err)
	}

	groupInfo := genericapiserver.APIGroupInfo{
		PrioritizedVersions:          []schema.GroupVersion{projectv1.SchemeGroupVersion},
		VersionedResourcesStorageMap: map[string]map[string]apiserverrest.Storage{
			"v1": {
				"projects":        projectrest.NewProjectStorage(kubeClient, serverConfig.Authorization.Authorizer),
				"projectrequests": projectrest.NewProjectRequestStorage(kubeClient),
			},
		},
		OptionsExternalVersion: &schema.GroupVersion{Group: projectv1.GroupName, Version: "v1"},
		Scheme:                 scheme,
		ParameterCodec:         metav1.ParameterCodec,
		NegotiatedSerializer:   codecs,
	}

	if err := server.InstallAPIGroup(&groupInfo); err != nil {
		log.Fatalf("Failed to install API group: %v", err)
	}

	stopCh := genericapiserver.SetupSignalHandler()
	if err := server.PrepareRun().Run(stopCh); err != nil {
		log.Fatalf("Failed to run server: %v", err)
	}
}
