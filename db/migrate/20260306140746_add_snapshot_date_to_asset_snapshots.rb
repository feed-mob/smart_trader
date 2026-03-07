class AddSnapshotDateToAssetSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :asset_snapshots, :snapshot_date, :date
  end
end
