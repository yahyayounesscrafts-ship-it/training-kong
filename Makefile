.PHONY: init-snap
init-snap:
	docker-compose -f docker-compose.yml run terragrunt terragrunt init --terragrunt-working-dir /data/tenants/snap

.PHONY: init-recette
init-recette:
	docker-compose -f docker-compose.yml run terragrunt terragrunt init --terragrunt-working-dir /data/tenants/recette

.PHONY: apply-snap
apply-snap:
	docker-compose -f docker-compose.yml run terragrunt terragrunt run-all apply -auto-approve --terragrunt-non-interactive --terragrunt-working-dir /data/tenants/snap

.PHONY: apply-recette
apply-recette:
	docker-compose -f docker-compose.yml run terragrunt terragrunt run-all apply -auto-approve --terragrunt-non-interactive --terragrunt-working-dir /data/tenants/recette

.PHONY: init-local
init-snap-local:
	docker-compose -f docker-compose-local.yml run terragrunt terragrunt init --terragrunt-working-dir /data/tenants/local

.PHONY: apply-local
apply-snap-local:
	docker-compose -f docker-compose-local.yml run terragrunt terragrunt run-all apply -auto-approve --terragrunt-non-interactive --terragrunt-working-dir /data/tenants/local
