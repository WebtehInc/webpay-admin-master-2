# WebPay Admin

Online banking with mPOS backend

## Installation

- install ruby version from `.ruby-version`
- set ENV variables in `.env` file, use `.env.example.txt` file as template
- create `webpay_(test/dev/prod)` database
- run `bundle`
- run `rake db:migrate`
- add webpay entry to host file: `127.0.0.1 webpay-admin`
- start local server: `rerun -- puma -v -t 1:1 -b tcp://webpay:5555`
- install webpay-spa-admin for frontend

## POS binaries managment configuration

- simlink files/pos/binaries/downloads to downloads folder in public app

## Feature configuration

### Acquiring data

- enable feature by adding `ACQUIRING=true` env variable
- create `settings/acquiring_data.rb`, use .example file as template
