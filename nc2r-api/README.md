<p align="center"><a href="https://laravel.com" target="_blank"><img src="https://raw.githubusercontent.com/laravel/art/master/logo-lockup/5%20SVG/2%20CMYK/1%20Full%20Color/laravel-logolockup-cmyk-red.svg" width="400" alt="Laravel Logo"></a></p>

<p align="center">
<a href="https://github.com/laravel/framework/actions"><img src="https://github.com/laravel/framework/workflows/tests/badge.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/dt/laravel/framework" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/v/laravel/framework" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/l/laravel/framework" alt="License"></a>
</p>

## About Laravel

Laravel is a web application framework with expressive, elegant syntax. We believe development must be an enjoyable and creative experience to be truly fulfilling. Laravel takes the pain out of development by easing common tasks used in many web projects, such as:

- [Simple, fast routing engine](https://laravel.com/docs/routing).
- [Powerful dependency injection container](https://laravel.com/docs/container).
- Multiple back-ends for [session](https://laravel.com/docs/session) and [cache](https://laravel.com/docs/cache) storage.
- Expressive, intuitive [database ORM](https://laravel.com/docs/eloquent).
- Database agnostic [schema migrations](https://laravel.com/docs/migrations).
- [Robust background job processing](https://laravel.com/docs/queues).
- [Real-time event broadcasting](https://laravel.com/docs/broadcasting).

Laravel is accessible, powerful, and provides tools required for large, robust applications.

## Learning Laravel

Laravel has the most extensive and thorough [documentation](https://laravel.com/docs) and video tutorial library of all modern web application frameworks, making it a breeze to get started with the framework. You can also check out [Laravel Learn](https://laravel.com/learn), where you will be guided through building a modern Laravel application.

If you don't feel like reading, [Laracasts](https://laracasts.com) can help. Laracasts contains thousands of video tutorials on a range of topics including Laravel, modern PHP, unit testing, and JavaScript. Boost your skills by digging into our comprehensive video library.

## Laravel Sponsors

We would like to extend our thanks to the following sponsors for funding Laravel development. If you are interested in becoming a sponsor, please visit the [Laravel Partners program](https://partners.laravel.com).

### Premium Partners

- **[Vehikl](https://vehikl.com)**
- **[Tighten Co.](https://tighten.co)**
- **[Kirschbaum Development Group](https://kirschbaumdevelopment.com)**
- **[64 Robots](https://64robots.com)**
- **[Curotec](https://www.curotec.com/services/technologies/laravel)**
- **[DevSquad](https://devsquad.com/hire-laravel-developers)**
- **[Redberry](https://redberry.international/laravel-development)**
- **[Active Logic](https://activelogic.com)**

## Contributing

Thank you for considering contributing to the Laravel framework! The contribution guide can be found in the [Laravel documentation](https://laravel.com/docs/contributions).

## Code of Conduct

In order to ensure that the Laravel community is welcoming to all, please review and abide by the [Code of Conduct](https://laravel.com/docs/contributions#code-of-conduct).

## Security Vulnerabilities

If you discover a security vulnerability within Laravel, please send an e-mail to Taylor Otwell via [taylor@laravel.com](mailto:taylor@laravel.com). All security vulnerabilities will be promptly addressed.

## License

The Laravel framework is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).

## Running the API as a service (auto-start + auto-restart)

- **Windows:** open PowerShell *as Administrator*, run `scripts\install-autostart-windows.ps1`. The API starts at boot (no login needed, also after a power cut) and `start-server.bat` restarts it forever if it dies. Without admin it starts at logon instead. Remove with `uninstall-autostart-windows.ps1`.
- **Linux:** edit and install `scripts/nc2r-api.service` (see header comments) with `systemctl enable --now`. systemd starts it at boot and uses `Restart=always`. `scripts/start-server.sh` is an equivalent supervisor for non-systemd setups.
- Restarts are logged to `storage/logs/server-restarts.log`. Host/port can be changed with `NC2R_HOST` / `NC2R_PORT`.

### Production deployment checklist

- `.env`: `APP_ENV=production`, `APP_DEBUG=false`, a real `APP_URL`, and `php artisan key:generate` done once.
- Run `composer install --no-dev --optimize-autoloader`, `php artisan migrate --force`, `php artisan config:cache route:cache`.
- `artisan serve` is PHP's built-in server: fine for a small private/LAN deployment. For public traffic use nginx/Apache + php-fpm (document root `public/`) and TLS.
- Make `storage/` and `bootstrap/cache/` writable by the service user, and back up `database/database.sqlite`.

## Google / Facebook login (alongside email + password)

The app signs in with the provider, sends the provider token to `POST /api/auth/google` (`id_token`) or `POST /api/auth/facebook` (`access_token`), and the server verifies it and returns the normal Sanctum token. A social login with the same email links to the existing account (Facebook never links to admin accounts). Buttons only appear in the app once configured.

**Google** (Google Cloud Console -> APIs & Services -> Credentials)
1. Configure the OAuth consent screen.
2. Create an OAuth client of type **Web application** (its ID is the *server client ID*) and one of type **Android** (package name + SHA-1 from `cd android; ./gradlew signingReport`).
3. `.env`: `GOOGLE_CLIENT_IDS=<web client id>` (comma-separate extra IDs if needed), then `php artisan config:clear`.
4. Run the app with `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>`.

**Facebook** (developers.facebook.com -> Create app -> Consumer -> add *Facebook Login*)
1. `.env`: `FACEBOOK_APP_ID=...` and `FACEBOOK_APP_SECRET=...`.
2. Android: add the App ID/Client Token to `android/app/src/main/res/values/strings.xml` and the manifest as described at https://facebook.meta.com/ (flutter_facebook_auth docs), and register the package name + key hash in the Facebook app.
3. Run the app with `--dart-define=FACEBOOK_ENABLED=true`. Facebook apps in Development mode only allow testers/admins until you switch to Live.

Google/Facebook buttons are mobile/web only (not Windows desktop).

## Docker (production server)

The stack in `docker-compose.yml` runs the API on Apache + PHP 8.3 with a read-only root filesystem, no Linux capabilities beyond what Apache needs, and `no-new-privileges`.

1. Copy the project to the server and place your real `.env` next to `docker-compose.yml`. It is git-ignored and is read at runtime through `env_file`, so it is never copied into the image.
2. `docker compose up -d --build`
3. The app is served at the `APP_URL` port (`http://localhost:8000` by default). Health: `docker compose ps`.
4. Migrations are not run automatically. Run them only when needed: `docker compose exec api php artisan migrate --force`.

The compose file forces `APP_ENV=production`, `APP_DEBUG=false` and `LOG_LEVEL=error`, overriding `.env`. Set `SESSION_SECURE_COOKIE=true` in `.env` only when you serve over HTTPS.
