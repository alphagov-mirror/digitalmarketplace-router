# Digital Marketplace PaaS Router

This is an Nginx application which acts as a proxy for all Digital Marketplace PaaS applications.

Requests are routed to the correct location based on the hostname:

| Hostname | Destination app |
| :--- | :--- |
| `api.*` | API |
| `search-api.*` | Search API |
| `www.*` | Front end apps |
| `assets.*` | S3 resources (or the front end apps, depending on the path) |

The router app also handles:
- Forwarding request headers
- Adding the Basic Auth header to frontend app requests (these apps' URLs cannot be accessed directly,
and must go via the router app)
- IP restrictions for `/admin` pages
- Serving the `robots.txt` static page
- Rate limiting
- 'Maintenance' mode (routing all requests to a static page)
- `gzip` settings for CSS and Javascript files

The app-level nginx configurations can be found in the [Docker base repo](https://github.com/alphagov/digitalmarketplace-docker-base).

## Testing nginx changes locally

There are two ways to test changes to the nginx configuration:

### make test-nginx

Assuming you have [Docker](https://docs.docker.com/engine/installation/) installed:

Running `make test-nginx` does the following:
- builds a new Docker image from your local repo (using the `Dockerfile`)
- starts running a container based on that image, using dummy environment variables
- starts up nginx inside the image (this takes a few seconds)
- runs `nginx -t` to check the config:

        nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
        nginx: configuration file /etc/nginx/nginx.conf test is successful

If the config test is successful, the container is stopped and removed. If there is a failure, the container
is preserved for investigation.

You can use `docker exec -i -t digitalmarketplacerouter_test /bin/bash` to look inside the container.


### docker-compose

This method uses Docker and `docker-compose` to build the router image.

Assuming you have [Docker](https://docs.docker.com/engine/installation/) and [docker-compose](https://docs.docker.com/compose/install/) installed:

  1. Make your changes. For example, in `templates/www.j2`:

    location /my-location {
        not_a_real_directive oh_dear;
    }

  2. Build your new Docker image version from your local changes (tag it with a sensible name if you like)

    $docker build -t digitalmarketplace/router:exciting_new_nginx_changes .

  3. Copy the example `docker-compose.yml.example` settings file to `docker-compose.yml` in your local directory.
   Update the settings with your local port(s) and the name of your new docker image version:

    version: '2'
    services:
      router:
        image: "digitalmarketplace/router:exciting_new_nginx_changes"
        ports:
          - "80:80"
        ...

  4. Run `docker-compose up` to start the container for the image. Any errors or warnings will appear on the docker compose output:

    $ docker-compose up
    Creating network "digitalmarketplacerouter_default" with the default driver
    Creating digitalmarketplacerouter_router_exciting_new_nginx_changes ...
    Creating digitalmarketplacerouter_router_exciting_new_nginx_changes ... done
    Attaching to digitalmarketplacerouter_router_exciting_new_nginx_changes
    router_1  | 2018-01-05 14:51:24,769 CRIT Supervisor running as root (no user in config file)
    router_1  | 2018-01-05 14:51:24,771 INFO supervisord started with pid 1
    router_1  | 2018-01-05 14:51:25,776 INFO spawned: 'nginx' with pid 14
    router_1  | 2018-01-05 14:51:25,778 INFO spawned: 'awslogs' with pid 15
    router_1  | Compiling api
    router_1  | Compiling assets
    router_1  | Compiling www
    router_1  | Compiling healthcheck
    2018/01/05 14:51:26 [emerg] 14#14: unknown directive "not_a_real_directive" in /etc/nginx/sites-enabled/www.conf:20

  5. Once the container has started successfully, nginx should be listening on the URL and port you configured,
  e.g. http://localhost:80/robots.txt should show a static page.

  6. Once you're done, clean up the image and container with `docker-compose down`. To stop the container without removing it,
  use `docker-compose stop`.

**Caveat:** This method is not ideal for locally testing frontend app routing. In production, PaaS handles this automagically
as the frontend apps are all on the same host - [more info about this is available on the DM manual](https://alphagov.github.io/digitalmarketplace-manual/application-architecture.html?highlight=routing#overall-architecture)).

More info on `docker-compose` commands: https://docs.docker.com/compose/reference/overview/
