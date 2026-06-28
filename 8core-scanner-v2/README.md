# 8Core Scanner v2.0

**Vlasnički softver — Sva prava pridržana**
(c) 2026 Tomislav Galić / 8Core
Web: https://8core.hr | Kontakt: info@8core.hr

---

## Opis

8Core Scanner je sigurnosni scanner za shared hosting okruženja.
Skenira korisničke račune na serveru tražeći zlonamjerne fajlove
(web shellovi, obfusciran PHP, sumnjive ekstenzije i slično),
a rezultate prikazuje kroz web panel s upravljanjem nalazima.

---

## Arhitektura

Projekt je podijeljen u dva odvojena dijela:

```
8core-scanner-v2/
├── scanner/        ← Web panel (PHP, radi pod web serverom)
└── 8core_scanner/  ← Root engine (Bash, radi kao root via cron)
```

**Web panel i root engine NE smiju biti na istoj putanji.**
Komunikacija između njih odvija se isključivo preko baze podataka (scan queue).

---

## Struktura paketa

```
8core-scanner-v2/
│
├── scanner/                    ← Sadržaj kopirati u WEB_APP_PATH
│   ├── index.php               ← Dashboard (nalazi)
│   ├── scan.php                ← Zahtjevi za skeniranje
│   ├── action.php              ← Akcije na nalazima
│   ├── login.php               ← Prijava
│   ├── logout.php              ← Odjava
│   │
│   ├── install/                ← Installer (zaštićen install.lock nakon instalacije)
│   │   ├── index.php           ← Korak-po-korak installer
│   │   ├── checks.php          ← Provjere okruženja + migracija logika
│   │   ├── migrate.php         ← Standalone migracija sheme (za nadogradnje)
│   │   ├── schema.sql          ← Referentna SQL shema
│   │   ├── install.lock.example
│   │   └── templates/
│   │       ├── config.sample.php
│   │       └── scanner-db.sample.conf
│   │
│   ├── admin/                  ← Admin panel
│   │   ├── index.php           ← Admin dashboard
│   │   ├── users.php           ← Upravljanje korisnicima
│   │   ├── rules.php           ← Pravila i definicije (IOC)
│   │   ├── ignore.php          ← Ignore lista
│   │   └── sidebar.php         ← Sidebar komponenta
│   │
│   ├── includes/               ← Zajednički PHP moduli
│   │   ├── config.sample.php   ← Predložak konfiguracije (pravi genira installer)
│   │   ├── config.php          ← GENERIRA INSTALLER (nije u paketu)
│   │   ├── db.php              ← PDO konekcija
│   │   ├── auth.php            ← Autentikacija i sesije
│   │   └── helpers.php         ← Pomoćne funkcije
│   │
│   └── assets/
│       ├── css/
│       │   └── scanner.css
│       ├── js/
│       │   ├── scanner.js
│       │   └── rules.js
│       └── img/                ← Logo, ikone, UI elementi (za budući razvoj)
│           └── .gitkeep
│
├── 8core_scanner/              ← Sadržaj kopirati u ROOT_ENGINE_PATH
│   ├── ioc_scan.sh             ← Bash IOC scanner engine
│   ├── scanner_worker.sh       ← Worker (cron job, radi kao root)
│   ├── scanner-db.conf.sample  ← Predložak DB konfiga (pravi genira installer)
│   ├── scanner-db.conf         ← GENERIRA INSTALLER / ručno (nije u paketu)
│   ├── bin/                    ← Planirane binarne skripte
│   ├── lib/                    ← Planirane biblioteke
│   ├── modules/                ← Planirani moduli
│   ├── rules/                  ← Planirana pravila u fajlovima
│   ├── migrations/             ← Planirane DB migracije
│   ├── logs/                   ← Log fajlovi (geniraju se pri radu)
│   └── quarantine/             ← Karantenizirani fajlovi
│
├── README.md
└── changelog.md
```

---

## Instalacija

### Preduvjeti

- PHP >= 7.4 s ekstenzijama: `pdo`, `pdo_mysql`, `mbstring`, `json`
- MySQL / MariaDB
- Root pristup serveru (za root engine)
- Web server (Apache / Nginx)

### Napomena o strukturi paketa

ZIP mape (`scanner/` i `8core_scanner/`) su **izvorišne mape paketa** — ne konačne instalacijske putanje.
Sadržaj iz ZIP mape `scanner/` kopira se u odabrani `WEB_APP_PATH`.
Sadržaj iz ZIP mape `8core_scanner/` kopira se u odabrani `ROOT_ENGINE_PATH`.

### Korak 1 — Postavljanje web panela

Raspakirajte ZIP i kopirajte **sadržaj mape `scanner/`** u željeni web path, npr.:

```bash
cp -r scanner/ /home/korisnik/public_html/scanner/
```

Na serveru mora nastati:

```
/home/korisnik/public_html/scanner/index.php
/home/korisnik/public_html/scanner/install/
/home/korisnik/public_html/scanner/includes/
/home/korisnik/public_html/scanner/admin/
/home/korisnik/public_html/scanner/assets/
```

Web aplikacija može biti instalirana na bilo kojoj putanji.
Installer automatski detektira lokaciju.

### Korak 2 — Pokretanje installera

Otvorite u pregledniku:

```
https://vasa-domena.hr/scanner/install/
```

Installer će:
1. Provjeriti PHP okruženje
2. Zatražiti DB podatke i putanje (WEB_APP_PATH, WEB_APP_URL, ROOT_ENGINE_PATH, QUARANTINE_PATH, LOG_PATH)
3. Kreirati sve potrebne tablice
4. Generirati `includes/config.php`
5. Generirati `install/generated-scanner-db.conf` (za root engine)
6. Zaključati se (kreira `install/install.lock`)

### Korak 3 — Postavljanje root enginea

```bash
# Kao root — kopirajte sadržaj mape 8core_scanner/ u odabrani ROOT_ENGINE_PATH:
mkdir -p /root/8core_scanner
cp -r 8core_scanner/* /root/8core_scanner/

# Kopirajte generiranu DB konfiguraciju iz installera:
# (put do web aplikacije može se razlikovati)
cp /home/korisnik/public_html/scanner/install/generated-scanner-db.conf \
   /root/8core_scanner/scanner-db.conf
chmod 600 /root/8core_scanner/scanner-db.conf

# Postavite prava izvršavanja:
chmod +x /root/8core_scanner/ioc_scan.sh
chmod +x /root/8core_scanner/scanner_worker.sh

# Kreirajte log i quarantine direktorije (ako nisu nastali kopijem):
mkdir -p /root/8core_scanner/logs
mkdir -p /root/8core_scanner/quarantine
chmod 700 /root/8core_scanner/quarantine
```

**Napomena:** `ROOT_ENGINE_PATH` je samo default prijedlog. Administrator bira stvarnu putanju
pri instalaciji — installer prihvaća bilo koju putanju.

### Korak 4 — Postavljanje cron joba

```bash
# Kao root (crontab -e):
* * * * * /root/8core_scanner/scanner_worker.sh >> /root/8core_scanner/logs/scanner_worker_cron.log 2>&1
```

Zamijenite `/root/8core_scanner/` sa stvarnom `ROOT_ENGINE_PATH` ako je drugačija.

---

## Konfiguracija

### Web konfiguracija (`includes/config.php`)

Generira installer. Ključne vrijednosti:

| Ključ              | Opis                                      |
|--------------------|-------------------------------------------|
| `db_host`          | MySQL host                                |
| `db_name`          | Naziv baze                                |
| `db_user`          | Korisnik baze                             |
| `db_pass`          | Lozinka baze                              |
| `root_engine_path` | Putanja root enginea                      |
| `scan_script`      | Putanja do `ioc_scan.sh`                  |
| `scan_log`         | Putanja do live log fajla                 |
| `quarantine_path`  | Putanja do karantena direktorija          |

### Root konfiguracija (`scanner-db.conf`)

| Varijabla          | Opis                                      |
|--------------------|-------------------------------------------|
| `DB_HOST`          | MySQL host                                |
| `DB_NAME`          | Naziv baze                                |
| `DB_USER`          | Korisnik baze                             |
| `DB_PASS`          | Lozinka baze                              |
| `ROOT_ENGINE_PATH` | Putanja root enginea                      |
| `QUARANTINE_PATH`  | Putanja karantena                         |
| `LOG_PATH`         | Putanja log direktorija                   |

---

## Sigurnost

- `includes/config.php` — NE commitati, NE javno dostupan
- `scanner-db.conf` — `chmod 600`, vlasnik root, van web roota
- `install/install.lock` — nastaje nakon instalacije, blokira reinstalaciju
- Root engine nalazi se van web roota
- Web panel ne može direktno izvršavati root naredbe

---

## Tok rada

```
Web panel                     Baza podataka           Root engine
─────────────────────         ─────────────────        ─────────────────────
Korisnik zatraži scan  ──►  scanner_scan_requests  ◄──  scanner_worker.sh
Pregled nalaza         ◄──  findings               ──►  ioc_scan.sh
Akcija (quarantine)    ──►  findings.action_status  ◄──  scanner_worker.sh
```

---

## Verzija

Trenutna verzija: **2.0.0** (2026-06-28)

Vidi `changelog.md` za povijest izmjena.
