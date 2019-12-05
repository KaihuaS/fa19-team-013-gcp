# fa19-team-013-gcp
## Team Information

| Name | NEU ID | Email Address |
| --- | --- | --- |
| Yi Xie | 001357166 | xie.yi3@husky.neu.edu |
| Kaihua Shi | 001388964 | shi.ka@husky.neu.edu |
| Fan Huang | 001352737 | huang.fa@husky.neu.edu |

## Usage
1. Create gcp project 
2. Create and download crendentials file from https://console.cloud.google.com/apis/credentials, name the file as fa19-team-013.json and save it in terraform root directory
3. Go each terraform module directory
4. Run ```terraform init```
5. Run ```terraform apply``` or ```terraform -var-file=terraform.tfvars``` if terraform.tfvars file exisits
6. Run ```terraform destroy``` if don't need this resources any more
7. The application module depend on network module, please run network module first.