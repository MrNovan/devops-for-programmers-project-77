# Makefile

# === Настройки ===
TF_DIR = terraform
ANSIBLE_DIR = ansible

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

ansible-deps:
	cd $(ANSIBLE_DIR) && ansible-galaxy install -r requirements.yml

deploy:
	cd $(ANSIBLE_DIR) && ansible-playbook playbook.yml -i inventory/hosts.ini --ask-vault-pass