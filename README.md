# devops-miniproject-3-kel1

# 🚀 Enterprise CI/CD Pipeline - End-to-End DevOps Automation

## 🎯 Gambaran Proyek
Proyek ini mengimplementasikan alur CI/CD otomatis, tangguh, dan aman menggunakan prinsip *Infrastructure as Code* (IaC), *Configuration as Code* (CaC), dan *DevSecOps*. 

Setiap perubahan kode (*commit*) akan melewati proses build otomatis, pemindaian kerentanan keamanan (Docker Scout), dan deployment tanpa campur tangan manusia ke Azure Cloud.

## 🏗️ Arsitektur Sistem
* **Source Code:** GitHub
* **CI/CD Orchestrator:** Jenkins (Containerized via JCasC)
* **Image Registry:** Docker Hub
* **Infrastructure Provisioning:** Terraform (Azure: 2 VM, VNet, Subnet, NSG)
* **Configuration Management:** Ansible
* **Security Scanning:** Docker Scout
* **Target Environment:** Docker Engine pada Azure Worker VM

## 📂 Struktur Repositori
- `/app` - Source code aplikasi beserta Dockerfile (Multi-stage).
- `/terraform` - Skrip provisioning infrastruktur Azure.
- `/ansible` - Playbook untuk instalasi dependencies dan JCasC.
- `/jenkins` - Jenkinsfile untuk logika CI/CD pipeline.

## 🛠️ Persiapan Menjalankan (Prerequisites)
Pastikan sudah terinstall:
- Docker
- Git
- Terraform
- Azure CLI
- Ansible
- Jenkins (atau akan dibuat via Ansible)

## ☁️ Setup Azure (Terraform Backend)
**1.1 Login ke Azure**
```
az login
```

**1.2 Buat Resource Group**
```
az group create --name rg-tfstate --location "East US"
```

**1.3 Buat Storage Account** 
```
az storage account create --name satfstatedevopskel1 ^
  --resource-group rg-tfstate ^
  --sku Standard_LRS ^
  --encryption-services blob
```

**1.4 Buat Container**
```
az storage container create --name tfstate ^
  --account-name satfstatedevopskel1
```

## 🐳 Tahap 1: Kontainerisasi & DevSecOps
**🎯 Tujuan**
- Membuat Docker image dari aplikasi
- Integrasi security scanning
- Pipeline gagal jika ada vulnerability

**🧱 Dockerfile**
```
# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .

# Stage 2: Production (Minimal Image)
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app ./   
USER node                      
EXPOSE 3000
CMD ["node", "main.js"]
```

**🔁 Pipeline Flow**

**Build Image**
```
docker build -t devops-app:test ./app
```

**Test Container**
```
docker run -d -p 3000:3000 --name test-app devops-app:test

curl http://localhost:3000/
curl http://localhost:3000/health

docker stop test-app && docker rm test-app
```

**Security Scan (DevSecOps)**

Untuk simulasi kondisi FAIL (ada CVE Critical/High), jalankan:
```
docker scout cves --exit-code --only-severity critical,high devops-app:test
echo "Exit code: $?"
```

**📌 Output Tahap 1**
<img width="822" height="439" alt="Screenshot 2026-04-21 204011" src="https://github.com/user-attachments/assets/e905a6f7-8e9e-416f-9b21-48e07601439b" />
<img width="1449" height="723" alt="Screenshot 2026-04-22 053203" src="https://github.com/user-attachments/assets/8399976b-1863-4c6c-b06d-6a2261d6b818" />
<img width="1453" height="217" alt="Screenshot 2026-04-22 052813" src="https://github.com/user-attachments/assets/58a78b77-503f-45a0-8cd9-3a3757bf6ec8" />
<img width="1431" height="292" alt="Screenshot 2026-04-22 052839" src="https://github.com/user-attachments/assets/c7cf6c4e-37a1-4b17-ba94-e8d20eece54c" />

**Keterangan:**
- Pipeline gagal pada tahap security scan
- Ditemukan 21 HIGH vulnerabilities
- Exit code = 2
- Gagal melakukan deployment karena terdapat CVE maka melakukan rollback
- Hal ini menunjukkan mekanisme DevSecOps berjalan dengan baik

## ☁️ Tahap 2: Infrastructure as Code (Terraform)
**🎯 Tujuan**

Provision infrastructure secara otomatis di Azure.

**🔧 Resource**
- 1 VM Jenkins
- 1 VM Deployment
- VNet + Subnet
- Network Security Group

**▶️ Eksekusi**
```
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

**📌 Output Tahap 2**

## ⚙️ Tahap 3: Configuration as Code (Ansible + JCasC)
**🎯 Tujuan**
Setup server dan konfigurasi Jenkins secara instan tanpa konfigurasi manual lewat UI (*Zero-Touch*).

**🔧 Strategi 2-Fase**
1.  **Fase 1:** Menjalankan Jenkins kontainer polos untuk instalasi plugin (Job DSL, JCasC, Git, dll).
2.  **Fase 2:** Injeksi file `jenkins.yaml` untuk membuat kredensial dan job pipeline secara otomatis.

**▶️ Eksekusi**
```bash
cd ansible
source .env && ansible-playbook -i inventory.ini setup.yml
```

## 🔍 Traceability & Monitoring
- **GitHub Webhook:** Sinkronisasi otomatis setiap kali ada `git push`.
- **Slack Notification:** Notifikasi real-time ke channel `#deployments` untuk setiap status build (Success/Fail).

## 🔁 Rollback Automation
Jika deployment baru gagal pada tahap *Smoke Test* atau *Security Scan*, Jenkins akan secara otomatis menjalankan kembali image dengan tag `:latest` (versi stabil sebelumnya) di VM Target untuk menjaga ketersediaan layanan.

<img width="1657" height="525" alt="Screenshot 2026-04-22 051438" src="https://github.com/user-attachments/assets/833544e2-0368-4edd-b2b1-ea12c53748d1" />

## 🌐 Akses Aplikasi
- **Aplikasi Utama:** `http://85.211.253.241`
- **Jenkins Dashboard:** `http://85.211.243.25:8080`
