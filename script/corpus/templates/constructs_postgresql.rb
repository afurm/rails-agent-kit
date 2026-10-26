# Schema constructs the parser has to understand, as `rails new` + PostgreSQL dumps them.
class AddSchemaConstructs < ActiveRecord::Migration[X]
  def change
    enable_extension "btree_gist"
    enable_extension "citext"
    create_enum :order_status, %w[pending paid shipped]

    create_table :orders, comment: "Orders, with a long table comment that keeps going, so the dumped " \
                                   "create_table line is a long one" do |t|
      t.references :account, null: false, foreign_key: true
      t.enum :status, enum_type: :order_status, default: "pending", null: false
      t.decimal :subtotal, precision: 10, scale: 2, null: false
      t.decimal :tax, precision: 10, scale: 2, null: false, default: 0
      t.virtual :total, type: :decimal, precision: 10, scale: 2, as: "subtotal + tax", stored: true
      t.string :notes, default: "line one\nline two, with a comma # and a hash"
      t.citext :coupon
      t.jsonb :metadata
      t.string :tags, array: true, default: []
      t.check_constraint "subtotal >= 0", name: "subtotal_non_negative"
      t.timestamps
    end
    add_check_constraint :orders, "tax >= 0", name: "tax_non_negative"

    create_table :order_items, primary_key: [:order_id, :position] do |t|
      t.bigint :order_id, null: false
      t.integer :position, null: false
      t.string :sku, null: false
    end

    create_table :bookings, id: :uuid do |t|
      t.bigint :room_id, null: false
      t.tsrange :during, null: false
      t.exclusion_constraint "room_id WITH =, during WITH &&", using: :gist, name: "no_overlapping_bookings"
    end

    # Rails 8.1 dumps tables of other schemas as "schema.table"; Rails 7.2 leaves them out of schema.rb.
    create_schema "reporting"
    if ActiveRecord.version >= Gem::Version.new("8.1")
      create_table "reporting.daily_totals" do |t|
        t.date :day, null: false
        t.decimal :total, precision: 12, scale: 2
      end
    end

    create_table :settings, id: false do |t|
      t.string :key, null: false
      t.text :value
    end
  end
end
