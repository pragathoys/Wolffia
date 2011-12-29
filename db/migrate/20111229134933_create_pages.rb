class CreatePages < ActiveRecord::Migration
  def change
    create_table :pages do |t|
      t.string :title
      t.string :seo
      t.text :keywords
      t.text :description
      t.text :content

      t.timestamps
    end
  end
end
