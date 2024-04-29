# https://traefik.io/blog/traefik-proxy-fully-integrates-with-hashicorp-nomad/

job "traefik" {
  datacenters = ["dc1"]
  type        = "service"

  group "traefik" {
    count = 1

    network {
      port  "http"{
         static = 8080
      }
      port  "admin"{
         static = 8181
      }
      port "metrics" {
        static = 8082
      }
    }

    service {
      name = "traefik-http"
      provider = "nomad"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dashboard.rule=Host(`traefik.localhost`)",
        "traefik.http.routers.dashboard.service=api@internal",
        "traefik.http.routers.dashboard.entrypoints=web",
      ]
    }

    task "server" {
      driver = "docker"
      config {
        image = "traefik:v2.8.0-rc1"
        ports = ["admin", "http", "metrics"]
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
        ]
        args = [
          "--api.dashboard=true",
          "--api.insecure=true", ### For Test only, please do not use that in production
          "--entrypoints.web.address=:${NOMAD_PORT_http}",
          "--entrypoints.traefik.address=:${NOMAD_PORT_admin}",
          "--providers.nomad=true",
          "--providers.nomad.endpoint.address=http://10.9.99.10:4646" ### IP to your nomad server 
        ]
      }
      template {
        data = <<EOF
          [entryPoints]
              [entryPoints.web]
              address = ":80"
              [entryPoints.metrics]
              address = ":8082"
          [api]
              dashboard = true
              insecure  = true
          [log]
              level = "DEBUG"
          # Enable Consul Catalog configuration backend.
          [providers.consulCatalog]
              prefix           = "traefik"
              exposedByDefault = false
              [providers.consulCatalog.endpoint]
                address = "127.0.0.1:8500"
                scheme  = "http"
          EOF
        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
