FROM golang:1.25 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o project-api .

FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/project-api .
EXPOSE 443
CMD ["./project-api"]
