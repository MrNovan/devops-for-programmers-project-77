# Makefile

# === Настройки ===
TF_DIR = terraform

# === Цели ===

init:
	cd $(TF_DIR) && terraform init

plan:
	cd $(TF_DIR) && terraform plan

apply:
	cd $(TF_DIR) && terraform apply

destroy:
	cd $(TF_DIR) && terraform destroy

clean:
	rm -rf $(TF_DIR)/.terraform*
	rm -rf $(TF_DIR)/terraform.tfstate*
	rm -rf $(TF_DIR)/.terraform.lock.hcl

gen-tfvars:
	./generate-tfvars.sh