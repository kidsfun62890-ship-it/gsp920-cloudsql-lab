# GSP920 — Securing a Cloud SQL for PostgreSQL Instance

ये scripts केवल lab में दिए गए GSP920 tasks के लिए हैं। इन्हें **lab के Cloud Shell** में, lab student account से, इसी क्रम में चलाएँ। किसी personal project/account पर न चलाएँ।

## One-by-one commands

```bash
curl -LO https://raw.githubusercontent.com/REPLACE_WITH_YOUR_GITHUB_USERNAME/gsp920-cloudsql-lab/main/01-create-cmek-instance.sh
chmod +x 01-create-cmek-instance.sh
./01-create-cmek-instance.sh
```

```bash
curl -LO https://raw.githubusercontent.com/REPLACE_WITH_YOUR_GITHUB_USERNAME/gsp920-cloudsql-lab/main/02-enable-audit-and-load-data.sh
chmod +x 02-enable-audit-and-load-data.sh
./02-enable-audit-and-load-data.sh
```

```bash
curl -LO https://raw.githubusercontent.com/REPLACE_WITH_YOUR_GITHUB_USERNAME/gsp920-cloudsql-lab/main/03-configure-iam-db-user.sh
chmod +x 03-configure-iam-db-user.sh
./03-configure-iam-db-user.sh
```

## Important lab-only manual check

GSP920 में Cloud SQL के लिए **IAM & Admin → Audit Logs** में Cloud SQL के **Admin read, Data read, और Data write** audit-log checkboxes enable करना scoring का हिस्सा हो सकता है। यह protected console setting है, इसलिए script इसे silently बदलने की कोशिश नहीं करती।

Task 2 का script data load और pgAudit configuration करता है। Task 3 IAM user बनाकर `orders.order_items` पर grant देता है और permitted तथा denied queries verify करता है।

## Expected duration

सामान्यतः Cloud SQL provisioning, restart और data import के कारण **15–30 मिनट** रखें; धीमे lab backend में **35 मिनट तक** लग सकते हैं। Lab timer के भीतर पूरा करें।

## Safety

Scripts project ID और active account को Cloud Shell configuration से पढ़ते हैं; credentials hardcode नहीं हैं। वे केवल `cloud-sql-keyring`, `cloud-sql-key`, `postgres-orders`, `orders`, pgAudit, IAM database user, और required table grant जैसे lab-scoped resources पर काम करते हैं।
