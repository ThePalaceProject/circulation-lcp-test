# circulation-lcp-test
Testbed for testing Readium LCP integration in [Circulation Manager](https://github.com/NYPL-Simplified/circulation).

## Architecture
Project consists of the following modules:
- [elasticsearch](./elasticsearch) is a Dockerized version of Elasticsearch with pre-installed analysis-icu plugin required by Circulation Manager
- [lcp-collection](./lcp-collection) is an ONIX collection of 3 books used for testing
- [lcp-docker](./lcp-docker) is a [Docker-based implementation of Readium LCP](https://github.com/amigoslibraryservices/lcp-docker)
- [lcp-docker-conf](./lcp-docker-conf) is a Dockerized application generating LCP configuration for LCP License and Status servers using confd
- [lcp-import](./lcp-import) is Docker image based on [nypl/circ-exec](https://hub.docker.com/r/nypl/circ-exec/) including a bash script for importing the LCP collection into Circulation Manager
- [proxy](./proxy) is a Dockerized nginx reversed proxy based on [docker-nginx-with-confd](https://github.com/sysboss/docker-nginx-with-confd) GitHub project

## Usage

### Preparing the local environment
1. Update all the submodules:
```bash
git submodule init
git submodule update --remote --recursive
```

2. Update the following host names in [.env](./.env) file:
- READIUM_LSDSERVER_HOSTNAME
- READIUM_FRONTEND_HOSTNAME
- MINIO_HOSTNAME
- CM_HOSTNAME

3. Replace all the host names with `127.0.0.1` in `etc/hosts` file:
```
127.0.0.1     lsdserver.lcp.hilbertteam.net
127.0.0.1     testfrontend.lcp.hilbertteam.net
127.0.0.1     minio.lcp.hilbertteam.net
127.0.0.1     cm.lcp.hilbertteam.net
```

3. Run `lcp-conf` first to generate configuration required by `lcpserver`, `lsdserver`, and `testfrontend`:
```bash
docker-compose run lcp-conf
```

4. Build the images:
```bash
docker-compose build
```

6. Run all the containers:
```bash
docker-compose up -d
```

7. Use `docker-compose ps` to confirm that all the containers started successfully. It may take some time for `mariadb` to start which can negatively affect `lcpserver`, `lsdserver`, and `testfrontend`. In this case wait until `mariadb` finishes the initialization process (you can check the logs using `docker-compose logs mariadb`) and then start all the remaining containers:
```bash
docker-compose up -d
```

8. Make sure that Elasticsearch started correctly. Sometimes when the disk capacity is low, Elasticsearch marks shards as read-only which doesn't allow to use it properly.
Check the logs using `docker-compose logs es` and if you see something suspicious execute the following requests to fix it:
```bash
curl -XPUT -H "Content-Type: application/json" http://localhost:9200/_cluster/settings -d '{ "transient": { "cluster.routing.allocation.disk.threshold_enabled": false } }'
curl -XPUT -H "Content-Type: application/json" http://localhost:9200/_all/_settings -d '{"index.blocks.read_only_allow_delete": null}'
```

### Setting up a MinIO instance
1. Log into MinIO's administrative interface located at `MINIO_HOSTNAME` using `AWS_S3_KEY` and `AWS_S3_SECRET` defined in [.env](./.env) file as credentials:

2. Create the following buckets as it's shown on the picture below:
- `covers` - public access bucket containig book covers
- `encrypted-books` (`READIUM_S3_BUCKET`) - public access bucket containing encrypted books
  ![Creating buckets in MinIO](docs/01-Creating-buckets-in-MinIO.png "Creating buckets in MinIO")

3. Grant public access to the buckets created before:
```bash
# Start the MinIO's command line client
docker run -it --entrypoint=/bin/sh --network container:circulation-lcp-test_minio_1 minio/mc

# Authenticate against the running MinIO instance
mc alias set local http://minio:9000 minioadmin minioadmin # Please use the credentials set in .env file

# Grant public access to covers bucket
mc policy set public local/covers

# Grant public access to covers encrypted-books
mc policy set public local/encrypted-books
```

### Setting up Circulation Manager
1. Open Circulation Manager's administrative interface located at `CM_HOSTNAME`

2. Set up a new administrative account

3. Create a new library using `LCP` as its short name as it's shown on the picture below:
> _`LCP` is used in LCP configuration and shouldn't be changed_

  ![Creating a new library](docs/02-Creating-a-new-library.png "Creating a new library")

4. Set up a search service using `http://es:9200` as Elasticsearch's URL:
  ![Creating a search service](docs/03-Creating-a-search-service.png "Creating a search service")

5. Set up a new MinIO storage as it's shown on the pictures below and using `AWS_S3_KEY` and `AWS_S3_SECRET` as credentials:
  ![Creating a MinIO storage service](docs/04-Creating-a-MinIO-storage-service.png "Creating a MinIO storage service")

  ![Creating a MinIO storage service](docs/05-Creating-a-MinIO-storage-service.png "Creating a MinIO storage service")

6. Set up a new LCP storage service:
  ![Creating an LCP storage service](docs/06-Creating-an-LCP-storage-service.png "Creating an LCP storage service")

  ![Creating an LCP storage service](docs/07-Creating-an-LCP-storage-service.png "Creating an LCP storage service")

7. Set up a new LCP collection:
> - *LCP License Server's input directory* has to be `/opt/readium/files` because it's defined in Dockerfile
> - *lcpencrypt's output directory* has to be a value of `CM_REPOSITORY`, it points to the *intermediate_repository*

  ![Creating an LCP collection](docs/08-Creating-a-new-LCP-collection.png "Creating an LCP collection")

  ![Creating an LCP collection](docs/09-Creating-a-new-LCP-collection.png "Creating an LCP collection")

8. Set up a patron authentication provider (for example, a basic authentication):
  ![Creating a basic authentication provider](docs/10-Creating-a-basic-authentication-provider.png "Creating a basic authentication provider")

### Import the LCP collection
1. Run [the import script](./lcp-import/run.sh) via in `nypl/circ-exec` Docker image:
```bash
docker-compose -f docker-compose.yml -f docker-compose.import.yml run import
```

### Test
1. Go to the Circulation Manager dashboard, select `A Dictionary in Hindi and English` and borrow it:
  ![Borrowing an LCP book](docs/11-Borrowing-an-LCP-book.png "Borrowing an LCP book")

2. Authenticate using the test patron credentials:
  ![Authenticating](docs/12-Authenticating-a-patron.png "Authenticating")

3. Download the book:
  ![Downloading an LCP book](docs/13-Downloading-an-LCP-book.png "Downloading an LCP book")

4. Find the downloaded file.
> Please note that this file must have `.lcpl` extension (this should be fixed in [this PR](https://github.com/NYPL-Simplified/opds-web-client/pull/279)). Until it's fixed please change its extension manually
  ![Accessing the downloaded LCP book](docs/14-Accessing-the-LCP-book.png "Accessing the downloaded LCP book")

5. Open the `.lcpl` file in Thorium Reader:
  ![Opening the LCP book in Thorium Reader](docs/15-Opening-the-LCP-book-in-Thorium-Reader.png "Opening the LCP book in Thorium Reader")

6. Get generated passphrase from Circulation Manager:
  ![Getting a passphrase from Circulation Manager](docs/16-Getting-passphrase-from-Circulation-Manager.png "Getting a passphrase from Circulation Manager")

7. Enjoy the book in Thorium Reader:
  ![LCP book opened in Thorium Reader](docs/17-LCP-book-opened-in-Thorium-Reader.png "LCP book opened in Thorium Reader")
