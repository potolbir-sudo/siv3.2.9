-- Post opening inventory value to accounting
-- This creates a journal entry to properly record inventory as an asset

DO $$
DECLARE
  v_inventory_value decimal(15,2);
  v_inventory_account_id uuid;
  v_equity_account_id uuid;
  v_je_id uuid;
  v_je_number text;
BEGIN
  -- Calculate total inventory value
  SELECT COALESCE(SUM(ii.quantity_on_hand * p.cost_price), 0)
  INTO v_inventory_value
  FROM inventory_items ii
  JOIN products p ON ii.product_id = p.id
  WHERE ii.quantity_on_hand > 0;

  IF v_inventory_value = 0 THEN
    RAISE NOTICE 'No inventory to post';
    RETURN;
  END IF;

  -- Get account IDs
  SELECT id INTO v_inventory_account_id FROM accounts WHERE code = '1200' LIMIT 1;
  SELECT id INTO v_equity_account_id FROM accounts WHERE code = '3000' LIMIT 1;

  IF v_inventory_account_id IS NULL OR v_equity_account_id IS NULL THEN
    RAISE EXCEPTION 'Required accounts not found (1200 or 3000)';
  END IF;

  -- Generate journal entry number and ID
  v_je_id := 'aaaa0000-0000-0000-0000-000000000001'::uuid;
  v_je_number := 'JE-OPENING-' || to_char(CURRENT_DATE, 'YYYYMMDD');

  -- Create journal entry (if not already exists)
  INSERT INTO journal_entries (id, entry_number, entry_date, description, reference_type, total_debit, total_credit, is_posted)
  VALUES (
    v_je_id,
    v_je_number,
    CURRENT_DATE,
    'Opening Inventory Balance - Product Import',
    'opening_balance',
    v_inventory_value,
    v_inventory_value,
    true
  )
  ON CONFLICT (id) DO NOTHING;

  -- Create journal lines: Debit Inventory, Credit Equity
  -- Line 1: Debit Inventory Asset
  INSERT INTO journal_lines (id, journal_entry_id, account_id, debit, credit, description, sort_order)
  VALUES (
    'aaaa0000-0000-0000-0000-000000000011'::uuid,
    v_je_id,
    v_inventory_account_id,
    v_inventory_value,
    0,
    'Opening inventory value from imported products',
    1
  )
  ON CONFLICT (id) DO NOTHING;

  -- Line 2: Credit Owner Equity
  INSERT INTO journal_lines (id, journal_entry_id, account_id, debit, credit, description, sort_order)
  VALUES (
    'aaaa0000-0000-0000-0000-000000000012'::uuid,
    v_je_id,
    v_equity_account_id,
    0,
    v_inventory_value,
    'Opening equity contribution - inventory',
    2
  )
  ON CONFLICT (id) DO NOTHING;

  -- Update account balances
  UPDATE accounts SET balance = balance + v_inventory_value WHERE id = v_inventory_account_id;
  UPDATE accounts SET balance = balance + v_inventory_value WHERE id = v_equity_account_id;

  RAISE NOTICE 'Posted opening inventory value: %', v_inventory_value;
END $$;