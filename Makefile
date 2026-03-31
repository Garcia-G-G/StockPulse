.PHONY: dev prod stop logs test test-unit test-integration lint lint-fix security console db-migrate db-seed db-shell redis-cli sidekiq-web routes

dev:
	docker compose -f docker-compose.dev.yml up --build

prod:
	docker compose up -d --build

stop:
	docker compose down

logs:
	docker compose logs -f

test:
	bundle exec rspec

test-unit:
	bundle exec rspec --exclude-pattern "spec/integration/**/*_spec.rb"

test-integration:
	bundle exec rspec spec/integration

lint:
	bundle exec rubocop

lint-fix:
	bundle exec rubocop -A

security:
	bundle exec brakeman -q

console:
	bin/rails console

db-migrate:
	bin/rails db:migrate

db-seed:
	bin/rails db:seed

db-shell:
	bin/rails dbconsole

redis-cli:
	redis-cli

sidekiq-web:
	@echo "Sidekiq Web UI available at http://localhost:3000/sidekiq"

routes:
	bin/rails routes
