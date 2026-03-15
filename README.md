# GrillPOS

🔥 Professional Restaurant Point of Sale System

GrillPOS is a modern desktop POS system designed specifically for grill restaurants such as kebab, kofta, and grilled chicken shops.

The system provides a fast cashier workflow, table management, menu control, and daily reporting — all running locally without requiring internet access.

GrillPOS is optimized for busy restaurants that need a reliable and simple cashier system.

---

# Overview

GrillPOS helps restaurant owners manage their daily operations efficiently.

The system includes tools for:

• Creating and managing orders  
• Managing restaurant tables  
• Organizing menu items  
• Tracking daily sales  
• Generating receipts  
• Monitoring restaurant performance  

The interface is designed to be **fast, simple, and touch-friendly** for cashiers.

---

# Features

## POS Sales Interface

Fast and simple cashier workflow.

Features include:

• Large food item buttons  
• Quick order creation  
• Real-time cart updates  
• Quantity editing  
• Instant checkout  

Example menu items:

- Kebab
- Kofta
- Grilled Chicken
- Shish Tawook
- Rice
- Salad
- Bread

---

## Table Management

Manage restaurant tables visually.

Each table shows:

• Table number  
• Table status (Available / Occupied)  
• Active order  

Cashiers can open orders directly from the table screen.

---

## Order Management

Track all restaurant orders easily.

Each order contains:

• Order number  
• Table number  
• Ordered items  
• Quantities  
• Total price  
• Order time  

Orders can be viewed in history for review.

---

## Receipt Printing

Supports **80mm thermal printers** commonly used in restaurants.

Receipt includes:

• Restaurant name  
• Order number  
• Items ordered  
• Quantities  
• Total price  
• Date and time  

---

## Reports

Managers can view important sales data such as:

• Daily revenue  
• Total orders  
• Best selling dishes  
• Sales summaries  

These reports help understand restaurant performance.

---

## User Roles

GrillPOS supports two user roles.

### Manager

Full access to system features:

• Reports  
• Settings  
• User management  
• System configuration  

### Cashier

Limited access for daily operation:

• Create orders  
• View invoices  
• Manage tables  

---

# Offline First System

GrillPOS works **completely offline** using a local database.

Benefits:

• No internet required  
• Faster performance  
• Reliable operation  
• Local data storage  

The database is automatically created on the first run.

---

# Technology Stack

Framework: Flutter Desktop  
Language: Dart  
Database: SQLite  
State Management: Bloc / Cubit  
Charts: fl_chart  
Printing: pdf & printing packages  
Dependency Injection: GetIt

---

# Project Structure

The project follows **Clean Architecture**.
lib/
├── core/
│ ├── components/
│ ├── constants/
│ ├── services/
│ ├── theme/
│ └── utils/
│
├── features/
│ ├── auth/
│ ├── dashboard/
│ ├── pos/
│ ├── orders/
│ ├── tables/
│ ├── menu/
│ ├── reports/
│ └── settings/
│
└── main.dart


This structure improves:

• code organization  
• scalability  
• maintainability  

---

# Screens

Main screens included in the system:

• Login Screen  
• Dashboard  
• POS Sales Screen  
• Tables Screen  
• Orders Screen  
• Reports Dashboard  
• Settings Screen  

---

# Installation

## Requirements

• Windows 10 or later  
• Flutter SDK  
• Visual Studio with Desktop C++ tools  
