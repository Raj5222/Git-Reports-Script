# 📘 Git Records

`git-records` is a **global Git utility** that displays recent Git branches in a **clean, numbered, tabular format** with strict validation and professional error handling.

It works from **any directory**, as long as you are inside a Git repository.

---

## ✨ Features

* ✅ Works as a **global command**
* ✅ Default shows **latest 10 records**
* ✅ Accepts a numeric limit (`git-records 5`)
* ✅ Clean **lined table**
* ✅ **Local / Remote** branch separation
* ✅ **Current branch highlighted**
* ✅ Strict input validation
* ✅ **Red highlighted error boxes**
* ✅ No raw Git or shell errors

---

# 📦Quick Installation
```
bash <(curl -fsSL https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/install.sh)
```
---
## 📦 Manual Installation

### 1️⃣ Create the script

Create the file:

```bash
sudo nano /usr/local/bin/git-records
```

Paste the **full script** provided earlier into this file.

Save and exit (`CTRL + O`, `ENTER`, `CTRL + X`).

---

### 2️⃣ Make it executable

```bash
sudo chmod +x /usr/local/bin/git-records
```

---

### 3️⃣ Verify installation

```bash
which git-records
```

Expected output:

```text
/usr/local/bin/git-records
```

---

## 🚀 Usage

### Default (shows latest 10)

```bash
git-records
```

---

### Show latest N records

```bash
git-records 5
git-records 20
git-records 100
```

---

### As a Git subcommand

Because the script name starts with `git-`, you can also run:

```bash
git records
```

---

## 📊 Output Example

```text
Git Records
Repository : /home/user/project
--------------------------------
Current Branch : feature/new-api
Local Records  : 4
Remote Records : 28
Total Records  : 32
Showing Latest : 10

+----+--------+-----------------+------------------------------------------+
| No | TYPE   | LAST COMMIT     | BRANCH                                   |
+----+--------+-----------------+------------------------------------------+
| 1  | LOCAL  | 2 hours ago     | feature/new-api                          |
| 2  | REMOTE | 2 hours ago     | origin/feature/new-api                   |
| 3  | REMOTE | 1 day ago       | origin/develop                           |
| 4  | LOCAL  | 3 days ago      | develop                                  |
+----+--------+-----------------+------------------------------------------+
```

---

## ❌ Error Handling (Professional & Clear)

### Invalid argument

```bash
git-records clear
```

```text
┌─ ERROR ───────────────────────────────────────────────┐
│ Message : Invalid argument                            │
│ Hint    : Please provide a positive number            │
│ Example : git-records 10                              │
└───────────────────────────────────────────────────────┘
```

---

### Zero or negative value

```bash
git-records 0
```

```text
┌─ ERROR ───────────────────────────────────────────────┐
│ Message : Invalid limit value                         │
│ Hint    : Limit must be greater than zero             │
│ Example : git-records 5                               │
└───────────────────────────────────────────────────────┘
```

---

### Very large / unsafe number

```bash
git-records 999999999999999
```

```text
┌─ ERROR ───────────────────────────────────────────────┐
│ Message : Limit value is too large                    │
│ Hint    : Please provide a reasonable number          │
│ Example : git-records 100                             │
└───────────────────────────────────────────────────────┘
```

---

### Not inside a Git repository

```bash
git-records
```

```text
┌─ ERROR ───────────────────────────────────────────────┐
│ Message : Not a Git repository                        │
│ Hint    : Run this command inside a Git project       │
└───────────────────────────────────────────────────────┘
```

---

## 🔒 Validation Rules

The input number must:

* Be numeric only (`^[0-9]+$`)
* Be greater than zero
* Have no leading zeros
* Be within a safe length (prevents shell overflow)

Anything else → **error and stop**.

---

## 🧹 Uninstall

To remove the command:

```bash
sudo rm /usr/local/bin/git-records
```

---

## 🧠 Notes

* Works on Linux and macOS
* No external dependencies
* Uses native Git commands only
* Safe for large repositories
* Designed for daily developer use
