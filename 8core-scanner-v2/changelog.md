# Changelog — 8Core Scanner

Sve značajne izmjene dokumentirane su u ovoj datoteci.
Format se temelji na [Keep a Changelog](https://keepachangelog.com/hr/1.0.0/).
Verzioniranje slijedi [Semantic Versioning](https://semver.org/lang/hr/).

---

## [2.0.0] — 2026-06-28

### Reorganizacija arhitekture (V2.0 paket)

Ovo izdanje ne donosi nove funkcionalnosti — radi se o potpunoj
reorganizaciji strukture projekta radi čišće osnove za daljnji razvoj.

#### Dodano

- **Struktura paketa `8core-scanner-v2/`** s jasnom podjelom na `web/` i `root/`
- **Installer** (`web/scanner/install/index.php`) — korak-po-korak instalacija s:
  - Provjerom PHP okruženja (verzija, ekstenzije, dozvole)
  - Unosom DB podataka i testom konekcije
  - Podesivim putanjama: `WEB_APP_PATH`, `WEB_APP_URL`, `ROOT_ENGINE_PATH`, `QUARANTINE_PATH`, `LOG_PATH`
  - Automatskim generiranjem `includes/config.php`
  - Automatskim generiranjem `install/generated-scanner-db.conf` za root engine
  - Pokretanjem migracije sheme baze
  - Zaključavanjem installera (`install.lock`) nakon uspješne instalacije
- **`install/checks.php`** — provjere okruženja i logika migracije odvojena u zasebni modul
- **`install/migrate.php`** — premješteno iz korijena web aplikacije u `install/` mapu; zaštićeno autentikacijom
- **`install/schema.sql`** — referentna SQL shema svih tablica
- **`install/install.lock.example`** — primjer lock fajla
- **`install/templates/config.sample.php`** — predložak PHP konfiguracije
- **`install/templates/scanner-db.sample.conf`** — predložak bash DB konfiguracije
- **`includes/config.sample.php`** — predložak koji zamjenjuje stvarni `config.php` u paketu
- **`root/8core_scanner/scanner-db.conf.sample`** — predložak koji zamjenjuje stvarni `scanner-db.conf`
- **`root/8core_scanner/logs/.gitkeep`** — prazni placeholder za log direktorij
- **`root/8core_scanner/quarantine/.gitkeep`** — prazni placeholder za karantena direktorij
- **`root/8core_scanner/bin/.gitkeep`** — rezerviran za buduće binarne skripte
- **`root/8core_scanner/lib/.gitkeep`** — rezerviran za buduće biblioteke
- **`root/8core_scanner/modules/.gitkeep`** — rezerviran za buduće module
- **`root/8core_scanner/rules/.gitkeep`** — rezerviran za buduća pravila u fajlovima
- **`root/8core_scanner/migrations/.gitkeep`** — rezerviran za buduće DB migracije
- **`README.md`** — dokumentacija strukture, instalacije i konfiguracije (na hrvatskom)
- **`changelog.md`** — ovaj fajl

#### Izmijenjeno

- **`includes/db.php`** — dodana automatska preusmjeravanja na installer ako `config.php` ne postoji
- **`includes/auth.php`** — prilagođene `require_login()` / `require_admin()` putanje za rad na proizvoljnoj dubini
- **`ioc_scan.sh`** (v3.1 → v3.2) — putanje (`CONFIG`, `RUN_LOG`) sada se detektiraju relativno prema lokaciji skripte uz podršku za `--config=` argument; log se sprema u `LOG_PATH` iz konfiguracije
- **`scanner_worker.sh`** (v1.2 → v1.3) — putanje (`CONFIG`, `SCANNER`, `LOG`, `QUARANTINE_BASE`) sada se detektiraju relativno prema lokaciji skripte; podršku za `LOG_PATH` i `QUARANTINE_PATH` iz konfiguracije; prosljeđuje `--config=` argument scanneru
- **`index.php`** — ažuriran link za migrate na `install/migrate.php`; verzija u sidebaru: `v2.0`
- **`login.php`** — ažurirana verzija u naslovu: `v2.0`
- **`scan.php`** — ažurirana verzija u sidebaru: `v2.0`
- **`admin/sidebar.php`** — ažurirana verzija: `Admin Panel v2.0`; popravljen `mb_strtoupper` za avatar
- **`admin/index.php`** — tekst `Active/Inactive` preveden na `Aktivan/Neaktivan`
- **`admin/users.php`** — tekst `Activate/Deactivate` preveden na `Aktiviraj/Deaktiviraj`; tekst `Set pass` preveden na `Postavi`
- Sve `include`/`require` putanje prilagođene novoj dubini direktorija

#### Uklonjeno

- **Stvarni `config.php`** iz paketa (sadrži lozinke — ne smije biti u repozitoriju)
- **Stvarni `scanner-db.conf`** iz paketa (sadrži lozinke — ne smije biti u repozitoriju)
- **Svi log fajlovi** (`*.log`, `ioc-debug.log`, `ioc-scan-live.log`, `scanner-worker.log`, `scanner_worker_cron.log`) — sadrže stvarne putanje, korisnike i nalaze
- **`debug.php`** iz korijena web aplikacije — osjetljiv dijagnostički alat koji ne smije biti javno dostupan bez zaštite

#### Sigurnost

- Installer se zaključava nakon uspješne instalacije (`install.lock`)
- `config.php` se NE isporučuje u paketu — generira ga installer
- `scanner-db.conf` se NE isporučuje u paketu — generira ga installer
- Root engine je van web roota
- Web panel ne može direktno izvršavati root naredbe

---

## [1.5.0] — 2026-05-xx *(rekonstruirano iz koda)*

### Poboljšanja web panela

#### Dodano

- **Pravila i definicije** (`admin/rules.php`) — CRUD sučelje za IOC pravila s tipovima: filename, path, regex, regex_content, SHA256, chmod, extension, filesize
- **Ignore lista** (`admin/ignore.php`) — kategorizirani popis ignoriranih fajlova, putanja, hasheva i korisnika
- **Bulk akcije** na nalazima — odabir više nalaza i primjena akcije odjednom
- **CSV uvoz/izvoz** pravila
- **scanner_ignore_list** tablica u bazi
- **scanner_rules** tablica u bazi
- **scanner_scan_requests** — queue sustav za zahtjeve skeniranja
- Podrška za više accounta po korisniku (`scanner_user_accounts` tablica)
- Prikaz `source_guess` i `source_type` u tablici nalaza
- Email polje za korisnike

#### Izmijenjeno

- Scan triggering premješten na queue logiku (scan.php → scanner_scan_requests → worker)
- Prošireni detalji nalaza: SHA-256, ctime, birth_time, quarantine_path
- Admin sidebar reorganiziran s grupiranjem po sekcijama

---

## [1.0.0] — 2026-04-xx *(rekonstruirano iz koda)*

### Inicijalno izdanje

#### Dodano

- Osnovna struktura web panela (login, dashboard, admin)
- PHP autentikacija s bcrypt lozinkama i session managementom
- PDO konekcija na MySQL/MariaDB
- Prikaz nalaza s filtiranjem po riziku, accountu, statusu i pretraživanjem
- Akcije na nalazima: checked, ignore, quarantine_requested, delete_requested
- Admin panel: upravljanje korisnicima s role-based pristupom
- Bash IOC scanner (`ioc_scan.sh`) koji radi kao root
- Bash worker (`scanner_worker.sh`) za procesiranje akcija
- Stat kartice: CRITICAL, HIGH, MEDIUM, ignored, quarantine req., delete req.
- `scanner_users`, `findings`, `scans`, `scanner_actions` tablice u bazi

---

*Ovaj changelog automatski se ažurira uz svako novo izdanje.*
