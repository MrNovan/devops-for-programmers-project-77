### Hexlet tests and linter status:
[![Actions Status](https://github.com/MrNovan/devops-for-programmers-project-77/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/MrNovan/devops-for-programmers-project-77/actions)

# 🚀 Инфраструктурный проект на Terraform

Этот проект разворачивает инфраструктуру в Yandex Cloud:
- 2 ВМ (веб-серверы)
- Балансировщик нагрузки (L7, HTTPS)
- Сервис баз данных (PostgreSQL)

Все команды управления описаны через `make`.


## 🔐 Перед началом
Убедитесь, что установлены:
   - [Terraform](https://developer.hashicorp.com/terraform/downloads) 
   - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) 

Сгенерируйте `terraform.auto.tfvars.json`:
```bash
make gen-tfvars
```

## 🛠 Как использовать

1. Инициализировать проект
```
make init
```
2. Проверить план изменений
```
make plan
```
3. Применить изменения
```
make apply
```
4. Удалить инфраструктуру
```
make destroy
```