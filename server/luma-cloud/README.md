# LUMA cloud save: tvoj server

Isto kao FOUNDERS cloud save, samo za LUMA. Igra **nikad ne spaja direktno na bazu**. Na serveru radi mali
program (API) koji jedini razgovara s bazom:

```
iPhone/Android  ──HTTPS──▶  Caddy (443)  ──▶  luma-cloud API (Node.js, 127.0.0.1:8788)  ──▶  MariaDB/MySQL (127.0.0.1:3306)
```

- Svaki mobitel dobije svoj gost-račun i igra sama sprema napredak na server.
- Igrač se može prijaviti preko **Applea, Googlea ili Facebooka**. Tako veže svoj save i vrati ga na novom mobitelu.
- Server od tih prijava sprema samo njihov ID korisnika, bez e-maila i imena. Tokeni se spremaju kao SHA-256.
- Baza ostaje zatvorena prema van.
- LUMA radi **na istom serveru kao Founders**, ali odvojeno: ima svoju bazu `luma`, svog korisnika baze, svoj
  servis `luma-cloud` (port 8788) i svoju domenu. Founders se ne dira.

Upute su za Ubuntu ili Debian. Pretpostavka je da su koraci iz Founders README-a (vatrozid, MariaDB,
Node.js, Caddy) već napravljeni. Naredbe se upisuju u terminal na serveru (preko SSH-a).

---

## 1. Domena

Treba nova adresa za LUMA, npr. `luma.scyde.dev`.

- Ako koristiš `scyde.dev`: kod registrara dodaj A zapis `luma` → javna IP adresa servera (ista kao za Founders).
- Ako koristiš DuckDNS: dodaj novo ime (npr. `luma-scyde`) s istom IP adresom.

Provjera (nakon par minuta): `ping luma.scyde.dev` mora pokazati IP servera.

## 2. Kod i baza

```bash
cd /opt && sudo git clone https://github.com/byscyde/luma-game.git /opt/luma-game
sudo mkdir -p /opt/luma-cloud
sudo cp -r /opt/luma-game/server/luma-cloud/* /opt/luma-cloud/
sudo mysql < /opt/luma-cloud/schema.sql
```

Korisnik baze samo za LUMA. **Smisli novu jaku lozinku**, nemoj koristiti onu od Foundersa:

```bash
sudo mysql -e "CREATE USER 'luma'@'localhost' IDENTIFIED BY 'OVDJE-JAKA-LOZINKA';
GRANT SELECT, INSERT, UPDATE, DELETE ON luma.* TO 'luma'@'localhost';
FLUSH PRIVILEGES;"
```

## 3. API servis

```bash
cd /opt/luma-cloud
sudo npm ci --omit=dev
sudo useradd --system --no-create-home --shell /usr/sbin/nologin luma
sudo cp luma-cloud.env.example /etc/luma-cloud.env
sudo nano /etc/luma-cloud.env       # DB_PASSWORD, ADMIN_PASSWORD i ključevi za prijavu (korak 6)
sudo chmod 600 /etc/luma-cloud.env
sudo cp luma-cloud.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now luma-cloud
sudo systemctl status luma-cloud     # treba pisati "active (running)"
curl http://127.0.0.1:8788/health    # treba vratiti {"ok":true}
```

Ako ne radi: `sudo journalctl -u luma-cloud -n 50`.

## 4. HTTPS (Caddy, isti kao za Founders)

Founders već ima svoj blok u `/etc/caddy/Caddyfile`. LUMA blok se **dodaje ispod** njega (ne briši Founders):

```bash
sed 's/luma.example.duckdns.org/luma.scyde.dev/' /opt/luma-cloud/Caddyfile.luma | sudo tee -a /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Provjera s bilo kojeg računala: `curl https://luma.scyde.dev/health` → `{"ok":true}`.

## 5. Admin stranica (web dashboard)

**https://luma.scyde.dev/admin**, prijava lozinkom `ADMIN_PASSWORD` iz `/etc/luma-cloud.env` (barem 12 znakova).

- **Pregled**: broj igrača, aktivni danas i u 7 dana, broj saveova te koliko ih je prijavljeno preko Applea, Googlea i Facebooka.
- **Popis igrača** s traženjem (ID, uređaj, apple/google/facebook).
- **Napredak**: Verdant i pet otoka (riješeni leveli), Lantern Café (razina, zadaci, lokacije). Možeš urediti novčiće, dragulje, energiju i esenciju.
- **Račun**: povezane prijave (odvezivanje), uređaji, odjava sa svih uređaja, brisanje igrača.
- **Napredno**: cijeli save kao JSON (provjerava se prije spremanja) i preuzimanje savea kao datoteke.
- **Kopije**: server sprema kopiju najviše jednom na sat dok igrač igra (zadnjih 20) i prije svake tvoje promjene. Kopiju vraćaš jednim klikom.

Kad promijeniš save, igrač na mobitelu dobije pitanje koji napredak želi zadržati.

## 6. Prijava preko Applea, Googlea i Facebooka

Server provjerava token svake prijave kod Applea, Googlea ili Facebooka. Zato u `/etc/luma-cloud.env` treba upisati
ID-eve aplikacije. Iste ID-eve trebam i ja za igru, pa mi ih pošalji (osim **App Secreta**: njega upiši samo na server).

| Postavka | Gdje se dobije |
|---|---|
| `APPLE_BUNDLE_IDS=com.scyde.luma` | Bundle ID igre (već upisan). U Apple Developer računu: Identifiers → com.scyde.luma → uključi **Sign in with Apple**. |
| `GOOGLE_CLIENT_IDS` | console.cloud.google.com → APIs & Services → Credentials. Napravi OAuth client ID tipa **iOS** (bundle `com.scyde.luma`), tipa **Android** (paket `com.scyde.luma` + SHA-1 potpisnog ključa) i tipa **Web application** (za Android prijavu). Upiši iOS i Web ID odvojene zarezom. |
| `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | developers.facebook.com → My Apps → Create App → dodaj **Facebook Login** → App settings → Basic. Dodaj platforme iOS (bundle `com.scyde.luma`) i Android (paket `com.scyde.luma` + key hash). Za igru mi treba i **Client Token** (Settings → Advanced). |

Nakon promjene: `sudo systemctl restart luma-cloud`.

## 7. Sigurnosna kopija (preporuka)

```bash
sudo mkdir -p /var/backups/luma
echo '15 3 * * * root mysqldump --single-transaction luma | gzip > /var/backups/luma/luma-$(date +\%F).sql.gz && find /var/backups/luma -mtime +14 -delete' | sudo tee /etc/cron.d/luma-backup
```

## Nadogradnja servera kasnije

```bash
cd /opt/luma-game && sudo git pull
sudo cp server/luma-cloud/*.js server/luma-cloud/admin.html server/luma-cloud/schema.sql server/luma-cloud/package*.json /opt/luma-cloud/
sudo mysql < /opt/luma-cloud/schema.sql
cd /opt/luma-cloud && sudo npm ci --omit=dev && sudo systemctl restart luma-cloud
```

---

## API (za programere)

| Metoda | Put | Tijelo | Odgovor |
|---|---|---|---|
| POST | `/v1/guest` | `{deviceId}` | `{playerId, token}`: novi gost |
| POST | `/v1/auth/apple\|google\|facebook` | `{token, nonce?}` (+ token gosta) | `{playerId, token, linked, switched, providers}` |
| GET | `/v1/me` | token | `{playerId, providers}` |
| POST | `/v1/unlink/:provider` | token | odveže prijavu |
| POST | `/v1/logout` | token | briše token |
| DELETE | `/v1/me` | token | briše igrača i sve njegove podatke (Apple traži brisanje računa u igri) |
| GET | `/v1/save/:key` | token | `{value, updatedAt}` ili 404 |
| PUT | `/v1/save/:key` | `{value}` + token | sprema (do 6 MB) |
| GET | `/health` | | `{ok:true}` |

Token se šalje kao `Authorization: Bearer <token>`.

Ako se prijavljeni račun već koristi na drugom igraču, server vrati tog igrača (`switched: true`). Igra tada
pita koji napredak zadržati.

Save igre (`luma_save`) ima oblik `"gz:" + base64(gzip(JSON))` s poljima `{format, savedAt, uploadId, device, data}`.

Testovi (lokalni MariaDB): `npm test`. Upute za testnog korisnika baze su na vrhu `test/server.test.js`.
