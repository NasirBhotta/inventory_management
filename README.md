# Inventory Management System (Flutter Desktop)

Offline-first Flutter desktop system for a fertilizer and agriculture shop.

## Proposal

### 1. Introduction
This project is a custom Flutter Desktop Application for a fertilizer and agriculture shop.  
The system is designed to work 100% offline for full data privacy and zero internet dependency.

### 2. Core System Features
- Product management for Urea, DAP, medicines, seeds, and feed
- Stock tracking for Stock In / Stock Out and live inventory levels
- Low-stock alerts when products reach minimum threshold
- Sales records with daily transaction logging and searchable history
- Reporting suite: daily sales, monthly summaries, and remaining stock
- Data security through local database with backup and restore
- Setup and support: installation and 1 month technical support

### 3. Development Timeline
- Estimated duration: 3 to 4 weeks (development, testing, deployment)

### 4. Project Investment
- Typical market price in Pakistan: 50,000 PKR to 70,000 PKR
- Introductory collaboration rate: **25,000 PKR** (one-time payment)
- Cost covers development resources, tools, database setup, and 4 weeks labor

### 5. Important Terms
- Scope includes only features listed above
- Major additions (cloud sync, barcode, mobile app) are quoted separately
- Future updates after deployment + 1 month support are charged separately
- Initial stock data entry is managed by shop staff (training provided)

## Current Implementation Status

This repository now includes a working offline desktop starter:
- Local SQLite database (`sqflite_common_ffi`)
- Product CRUD (add/list)
- Stock IN/OUT flows
- Sale entry and stock deduction
- Dashboard metrics and reports
- Local backup and restore (latest backup)

## Run Locally

```bash
flutter pub get
flutter run -d windows
```
