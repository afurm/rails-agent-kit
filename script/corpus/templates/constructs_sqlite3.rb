# Schema constructs the parser has to understand, as `rails new` + SQLite dumps them.
class AddSchemaConstructs < ActiveRecord::Migration[X]
  def change
    create_table :orders, comment: "Orders" do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :subtotal_cents, null: false
      t.integer :tax_cents, null: false, default: 0
      if ActiveRecord.version >= Gem::Version.new("8.0")
        t.virtual :total_cents, type: :integer, as: "subtotal_cents + tax_cents", stored: true
      end
      t.string :notes, default: "line one\nline two, with a comma # and a hash"
      t.json :metadata
      t.check_constraint "subtotal_cents >= 0", name: "subtotal_non_negative"
      t.timestamps
    end
    add_check_constraint :orders, "tax_cents >= 0", name: "tax_non_negative"

    create_table :order_items, primary_key: [:order_id, :position] do |t|
      t.bigint :order_id, null: false
      t.integer :position, null: false
      t.string :sku, null: false
    end

    create_table :settings, id: false do |t|
      t.string :key, null: false
      t.text :value
    end

    create_virtual_table :posts_search, :fts5, ["title", "body"] if respond_to?(:create_virtual_table)
  end
end
