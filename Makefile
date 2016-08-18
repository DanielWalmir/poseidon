run: clean depends build docs notebooks main api monitor storage printPlaces periodically
printPlaces:
	@docker ps --format "table {{.Names}}\thttp://{{.Ports}}" |sed 's/0.0.0.0/localhost/' | sed 's/->/ container:/'

periodically: clean-periodically build-periodically
	docker run --net=container:poseidon-monitor periodically

killcrap:
	find . -name \*.pyc -exec rm -rf {} \;
	find . -name __pycache__ -type d -exec rm -rf {} \;

api: clean-api build-api
	@ if [ ! -z "${DOCKER_IP}" ]; then \
		DOCKER_IP=$$(env | grep DOCKER_IP | cut -d':' -f2 | cut -c 3-); \
		docker_url=http://$$DOCKER_IP; \
	else \
		if [ ! -z "${DOCKERFORMAC}" ]; then \
			docker_url=http://127.0.0.1; \
		else \
			echo "No DOCKER_IP environment variable set."; \
			exit 1; \
		fi; \
	fi; \
	docker run --name poseidon-api -dP poseidon-api ; \
	portApi=$$(docker port poseidon-api 8001/tcp | sed 's/^.*://'); \
	api_url=$$docker_url:$$portApi; \
	echo "The API can be accessed here: $$api_url"; \
	echo

test: storage build

main: clean-main build-main
	docker run --name poseidon-main -it poseidon-main

storage: clean-storage build-storage
	@ if [ ! -z "${DOCKER_IP}" ]; then \
		DOCKER_IP=$$(env | grep DOCKER_IP | cut -d':' -f2 | cut -c 3-); \
		docker_url=$$DOCKER_IP; \
	else \
		if [ ! -z "${DOCKERFORMAC}" ]; then \
			docker_url=localhost; \
		else \
			echo "No DOCKER_IP environment variable set."; \
			exit 1; \
		fi; \
	fi; \
	docker run --name poseidon-storage -dp 27017:27017 -e DOCKER_IP=$$DOCKER_IP mongo >/dev/null; \
	port=$$(docker port poseidon-storage 27017/tcp | sed 's/^.*://'); \
	echo "poseidon-storage can be accessed here: $$docker_url:$$port"; \
	echo

monitor: storage api clean-monitor build-monitor
	@ if [ ! -z "${DOCKER_IP}" ]; then \
		DOCKER_IP=$$(env | grep DOCKER_IP | cut -d':' -f2 | cut -c 3-); \
		docker_url=http://$$DOCKER_IP; \
	else \
		if [ ! -z "${DOCKERFORMAC}" ]; then \
		docker_url=http://localhost; \
		else \
			echo "No DOCKER_IP environment variable set."; \
			exit 1; \
		fi; \
	fi; \
	portApi=$$(docker port poseidon-api 8001/tcp | sed 's/^.*://'); \
	docker run --name poseidon-monitor -dp 4444:8004 -e ALLOW_ORIGIN=$$docker_url:$$portApi poseidon-monitor ; \
	port=$$(docker port poseidon-monitor 8004/tcp | sed 's/^.*://'); \
	docker run --name mock-controller -dp 3333:8003 -e ALLOW_ORIGIN=$$docker_url:8003 mock-controller; \
	echo "poseidon-monitor can be accessed here: $$docker_url:$$port"; \
	echo

storage-interface: clean-storage-interface build-storage-interface storage
	@ if [ ! -z "${DOCKER_IP}" ]; then \
		DOCKER_IP=$$(env | grep DOCKER_IP | cut -d':' -f2 | cut -c 3-); \
		docker_url=http://$$DOCKER_IP; \
	else \
		if [ ! -z "${DOCKERFORMAC}" ]; then \
		docker_url=http://localhost; \
		else \
			echo "No DOCKER_IP environment variable set."; \
			exit 1; \
		fi; \
	fi; \
	docker run --name poseidon-storage-interface -dp 28000:27000 -e ALLOW_ORIGIN=$$docker_url:28000 -e DOCKER_IP=$$DOCKER_IP poseidon-storage-interface; \
	echo "poseidon-storage-interface up"; \
	echo

notebooks: clean-notebooks build-notebooks
	@ if [ ! -z "${DOCKER_IP}" ]; then \
		DOCKER_IP=$$(env | grep DOCKER_IP | cut -d':' -f2 | cut -c 3-); \
		docker_url=http://$$DOCKER_IP; \
	else \
		if [ ! -z "${DOCKERFORMAC}" ]; then \
			docker_url=http://localhost; \
		else \
			echo "No DOCKER_IP environment variable set."; \
			exit 1; \
		fi; \
	fi; \
	docker run --name poseidon-notebooks -w /notebooks -dP -v "$$(pwd):/notebooks" poseidon-notebooks jupyter notebook --ip=0.0.0.0 --no-browser >/dev/null; \
	port=$$(docker port poseidon-notebooks 8888/tcp | sed 's/^.*://'); \
	notebook_url=$$docker_url:$$port; \
	echo "The notebooks can be accessed here: $$notebook_url"

docs: clean-docs build
	@ if [ ! -z "${DOCKER_IP}" ]; then \
		DOCKER_IP=$$(env | grep DOCKER_IP | cut -d':' -f2 | cut -c 3-); \
		docker_url=http://$$DOCKER_IP; \
	else \
		if [ ! -z "${DOCKERFORMAC}" ]; then \
			docker_url=http://localhost; \
		else \
			echo "No DOCKER_IP environment variable set."; \
			exit 1; \
		fi; \
	fi; \
	docker run --name poseidon-docs -dP poseidon-docs; \
	port=$$(docker port poseidon-docs 8002/tcp | sed 's/^.*://'); \
	doc_url=$$docker_url:$$port; \
	echo; \
	echo "The docs can be accessed here: $$doc_url"

compose-install:
	# NOTE: you may need to use `sudo make compose-install` if not running as root
	curl -L https://github.com/docker/compose/releases/download/1.8.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose; \
	chmod +x /usr/local/bin/docker-compose; \


compose:
	@ if [ ! -z "${DOCKER_IP}" ]; then \
		DOCKER_IP=$$(env | grep DOCKER_IP | cut -d':' -f2 | cut -c 3-); \
		docker_url=$$DOCKER_IP; \
	else \
		if [ ! -z "${DOCKERFORMAC}" ]; then \
			docker_url=localhost; \
		else \
			echo "No DOCKER_IP environment variable set."; \
			exit 1; \
		fi; \
	fi; \
	export DOCKER_URL=$$docker_url; \
	docker-compose up -d --force-recreate

rabbit: clean-rabbit depends
	docker run -d -h rabbitmq --name rabbitmq -p 15672:15672 -p 5672:5672 rabbitmq:management

pcap-stats:
	# NOTE: this is a plugin module that can be stood up for testing rabbitmq and mongo
	# docker run --name pcap-stats --link rabbitmq:rabbitmq pcap-stats
	# use link to alias containers, 'rabbitmq' for name of rabbit-host container
	@docker ps -aqf "name=pcap-stats" | xargs docker rm -f
	@docker build -t pcap-stats -f plugins/heuristics/pcap_stats/Dockerfile plugins/heuristics/pcap_stats/

build: depends
	docker build -t poseidon-notebooks -f Dockerfile.notebooks .
	docker build -t poseidon-monitor  -f Dockerfile.monitor .
	docker build -t poseidon-main  -f Dockerfile.main .
	docker build -t mock-controller -f Dockerfile.mock .
	docker build -t poseidon-storage-interface -f Dockerfile.storage-interface .

build-periodically:
	docker build -t periodically -f Dockerfile.periodically .

build-api:
	cd api && docker build -t poseidon-api .

build-docs:
	docker build -t poseidon-docs -f Dockerfile.docs .

build-monitor:
	docker build -t poseidon-monitor -f Dockerfile.monitor .

build-notebooks:
	docker build -t poseidon-notebooks -f Dockerfile.notebooks .

build-main:
	docker build -t poseidon-main  -f Dockerfile.main .

build-mock-controller:
	docker build -t mock-controller -f Dockerfile.mock .

build-storage:
	docker pull mongo

build-storage-interface:
	docker build -t poseidon-storage-interface -f Dockerfile.storage-interface .

clean-all: clean depends
	@docker rmi poseidon-monitor
	@docker rmi poseidon-storage
	@docker rmi poseidon-main
	@docker rmi poseidon-api
	@docker rmi periodically
	@docker rmi poseidon-storage-interface

clean-mock-controller:
	@docker ps -aqf "name=mock-controller" | xargs docker rm -f || echo

clean-periodically: depends
	@docker ps -afq "name=periodically" | xargs docker rm -f || echo

clean-storage: depends
	@docker ps -aqf "name=poseidon-storage" | xargs docker rm -f || echo

clean-monitor: depends
	@docker ps -aqf "name=poseidon-monitor" | xargs docker rm -f || echo

clean-main: depends
	@docker ps -aqf "name=poseidon-main" | xargs docker rm -f || echo

clean-docs: depends
	@docker ps -aqf "name=poseidon-docs" | xargs docker rm -f || echo

clean-api: depends
	@docker ps -aqf "name=poseidon-api" | xargs docker rm -f || echo

clean-notebooks: depends
	@docker ps -aqf "name=poseidon-notebooks" | xargs docker rm -f || echo

clean-storage-interface: depends
	@docker ps -aqf "name=poseidon-storage-interface" | xargs docker rm -f || echo

clean-rabbit:
	@docker ps -aqf "name=poseidon-rabbit" | xargs docker rm -f || echo

clean: clean-docs clean-notebooks depends
	#@docker ps -aqf "name=poseidon" | xargs docker rm -f
	#@docker ps -aqf "name=poseidon-api" | xargs docker rm -f

nuke-containers:
	# WARNING: this deletes all containers, not just poseidon ones
	@docker rm -f $$(docker ps -a -q) || echo

depends:
	@echo
	@echo "checking dependencies"
	@echo
	docker -v

.PHONY: run test docs build notebooks clean clean-all clean-notebooks clean-docs depends
