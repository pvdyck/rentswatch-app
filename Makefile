install:
	npm install
	bower install

run:
	grunt serve
	
build:
	grunt --force

deploy: build
	heroku docker:release -a rentswatch-app