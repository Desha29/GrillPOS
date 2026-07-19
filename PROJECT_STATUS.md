# GrillPOS implementation status

Updated: 19 July 2026

This document distinguishes working code from planned capabilities. A feature is
listed as complete only when its workflow and persistence are present in the
repository. Hardware and field testing are called out separately.

## Completed foundation

- Responsive Flutter application for Windows, mobile, and web targets.
- Manager and cashier login, user administration, shifts, activity history,
  permissions at navigation level, and automatic password-hash migration.
- Offline SQLite database with migrations, indexes, WAL mode, integrity checks,
  checkpoints, backup/restore UI, and recovery services.
- Menu categories and menu items with Arabic/English names, units, prices,
  availability, preparation time, and persistent product images.
- Restaurant POS cart with fractional quantities, dine-in/takeaway/delivery,
  table selection, tax calculation, notes, and persisted checkout.
- Restaurant tables with availability, occupancy, reservation, cleaning, and
  active-order assignment.
- Order board with persisted items, real payment transactions, and protected
  forward-only lifecycle statuses.
- Sales summaries, top-item reports, category reports, and daily revenue trends.
- Theme support, responsive navigation, loading/empty/error components, and
  data-management screens.

## Computer service module completed in this milestone

- Customer records linked to repair work.
- Repair intake with device type, brand, model, serial number/IMEI,
  accessories, issue, priority, estimate, deposit, and contact details.
- Unique professional repair-ticket numbers.
- Repair lifecycle: received, diagnosis, approval, in progress, waiting for
  parts, ready, delivered, and cancelled.
- Technician assignment, diagnosis/work notes, final cost, payments, and
  outstanding balance calculation.
- Persisted status-history audit records.
- Search across ticket number, customer, phone, device, and serial number.
- Operational dashboard for open, ready, urgent, and outstanding repairs.
- Responsive ticket list and editing workflow integrated into main navigation.
- Schema migration from database version 10 to 11 without removing restaurant
  data.

## Reliability and security completed in this milestone

- Corrected the ignore rule that accidentally excluded every source `data`
  folder from version control.
- Removed login password logging.
- Added salted PBKDF2-HMAC-SHA256 password storage and constant-time checks.
- Existing plaintext accounts are upgraded automatically after a valid login.
- Added tests for password storage, repair-domain rules, and database schema.
- Static analysis: zero errors and zero warnings.
- Automated tests: passing.
- Windows release build: passing.

## Professional dashboard and authorization completed

- Redesigned dashboard quick actions with descriptions, responsive cards, and
  role-aware shortcuts for restaurant and computer-service work.
- Redesigned recent-order cards with status/payment badges, timing, item count,
  responsive compact layouts, hover states, and clear order totals.
- Removed the dashboard pattern/background image in dark mode and replaced it
  with a clean solid dark surface.
- Fixed the recent-order runtime crash caused by combining intrinsic sizing
  with `LayoutBuilder`; a widget regression test now protects this layout.
- Added an in-app notification center for active and delayed orders.
- Replaced inconsistent snack bars with a unified professional message overlay
  for success, error, warning, information, actions, and logout confirmation.
- Centralized manager/cashier authorization for routes and sensitive actions.
  Inventory, reports, users, settings, menu administration, refunds, and day
  closing are manager-only; operational restaurant and repair work remains
  available to cashiers.
- Made logout resilient so audit/checkpoint failures cannot leave a user signed
  in locally.

## Professional Menu, POS, and Orders milestone completed

- Redesigned Menu management with responsive KPI cards, category and
  availability filters, fast search, professional product cards, and polished
  create/edit/delete dialogs.
- Added image selection to menu products. Selected files are copied into the
  persistent GrillPOS data directory rather than referencing a temporary or
  movable source file.
- Product images now appear consistently in Menu management and the POS catalog,
  with safe placeholders for missing or unreadable files.
- Redesigned POS for desktop and compact layouts with a searchable visual
  catalog, category navigation, clearer cart controls, order-type/table
  selection, totals, notes, and checkout feedback.
- POS checkout now creates the order header, every line, and dine-in table
  assignment in one SQLite transaction. Invalid items or occupied tables roll
  the entire checkout back instead of leaving partial orders.
- Redesigned Orders with operational KPIs, search, date/status filters, delayed
  order cues, responsive list/grid layouts, and a complete order-detail view.
- Order status changes are forward-only and concurrency-safe. Completed and
  cancelled orders are terminal, completion requires full payment, and paid or
  partially paid orders cannot be cancelled without an explicit refund flow.
- Recording an order payment now inserts a cent-rounded payment ledger row with
  method, reference, cashier, and timestamp instead of only changing a status
  flag.
- Dine-in tables are released atomically when an order is completed or safely
  cancelled, and collision-safe order numbers support rapid checkout.

## Professional Users, Tables, and invoice reliability milestone completed

- Redesigned Users management with responsive operational statistics, search,
  role filters, clear manager/cashier cards, and polished create/edit/delete
  dialogs.
- User administration is enforced at the action layer as well as in the UI.
  Duplicate usernames are rejected, a signed-in account cannot delete or
  demote itself, and the final manager account cannot be removed or demoted.
- Redesigned Tables management with capacity/status statistics, search, section
  and status filters, responsive table cards, and professional add/edit/detail/
  delete dialogs.
- Table creation is transaction-safe with automatic unique numbering and input
  validation. Metadata edits preserve active-order state, manual controls cannot
  forge occupancy, and tables with active or historical orders cannot be
  deleted.
- Fixed the checkout invoice crash caused by a saved logo path that was moved or
  deleted. The invoice now checks custom files safely and falls back to the
  bundled GrillPOS logo.
- Restaurant invoice PDF fonts now load from bundled assets rather than relying
  on a network download at print time.
- Added regression tests for missing invoice logos and table lifecycle/history
  integrity.

## Inventory milestone completed

- Manager-only inventory workspace integrated into the sidebar and dashboard
  quick actions.
- Product catalog for computer parts, accessories, and serialized devices with
  SKU, barcode, category, brand, model, cost, sell price, low-stock level,
  supplier, and warranty period.
- Supplier records with contact, phone, email, address, tax number, and notes.
- Unique serial-number intake for computers and warranty-tracked devices.
- Non-serialized stock adjustments with negative-stock protection and required
  adjustment reasons.
- Stock-movement audit ledger with user, quantity, cost, note, and timestamp.
- Inventory overview for product count, low stock, serialized units, and total
  cost value, plus search and low-stock filters.
- SQLite migration from version 11 to 12, preserving existing restaurant and
  repair data.
- End-to-end database tests for suppliers, serialized products, stock intake,
  valuation, and movement history.

## Computer quotations and sales milestone completed

- Professional Computer Sales workspace integrated into the sidebar and
  dashboard for both managers and cashiers.
- Customer search and creation, quotation creation/editing/cancellation,
  expiry dates, discounts, tax, notes, and collision-safe document numbers.
- Searchable computer-product catalog with stock, price, cost, warranty, and
  required serial selection for serialized devices.
- Active, unexpired quotations reserve their selected serial numbers; conversion
  revalidates stock and serial ownership inside the sale transaction.
- Quotation-to-sale conversion records current inventory cost, decrements stock,
  marks serials sold, links the customer, and creates auditable stock movements.
- Optional split initial payments and later balance payments with cash, card,
  bank transfer, mobile wallet, references, notes, and cent-level validation.
- Manager-only partial/full returns restore nonserialized stock and exact serial
  records, reverse the original inventory cost, and persist return/refund
  history atomically.
- Refund requirements are calculated from net payments and the post-return
  effective balance. Missing, short, or excessive refunds roll back the return,
  preventing lost customer credit or contradictory balances.
- Professional quotation/invoice PDFs include products, serial numbers,
  warranty periods, payment totals, signatures, and a warranty certificate;
  printing and PDF sharing are available from the document view.
- SQLite migration from version 12 to 13 preserves restaurant, repair, and
  inventory data while adding computer document, payment, serial-link, return,
  refund, counter, index, constraint, and immutable-number structures.
- Authorization is enforced again at the action layer: computer-sale actors are
  taken from the authenticated session, and returns/refunds require a manager
  even if a caller supplies forged actor data.

## Present but not production-complete

- Restaurant receipt output and real 58/80 mm printers still need field testing
  and printer-specific configuration. Computer PDFs are implemented, but also
  require validation on the business's actual printer models.
- Restaurant-order refunds and partial/split tender entry are not yet exposed as
  a complete cashier workflow. The current order flow safely blocks cancellation
  after any payment rather than silently losing money.
- Shift cash reconciliation does not yet combine restaurant, repair, and
  computer-sale tenders into a single closing worksheet.
- The restaurant menu does not yet deduct recipe ingredients from stock.
- Database backup/restore does not yet package copied product images and other
  managed assets with the SQLite backup.
- Backup and checkpoint workflows exist; restore should receive destructive and
  interrupted-operation acceptance testing with real business data.
- Sync scheduling exists, but there is no cloud API, tenant authentication, or
  conflict-resolution implementation.
- Roles are currently manager/cashier in the application model. Waiter,
  kitchen, technician, and inventory roles require a permission-matrix upgrade.

## Recommended next milestone

1. Add restaurant split tenders, manager refund documents, receipt reprint, and
   unified shift cash reconciliation.
2. Connect restaurant recipes to ingredient inventory and low-stock alerts.
3. Add printer profiles and field-test restaurant receipts, computer invoices,
   warranty sheets, and repair-intake tickets on the target hardware.
4. Include managed product/logo assets in verified backup and restore packages.
5. Expand role permissions for waiter, kitchen, technician, and inventory staff,
   with explicit audit events for every financial change.
6. Add cloud synchronization only after the expanded local transaction model is
   stable and restore-tested.
