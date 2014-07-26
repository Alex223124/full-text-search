Thing.delete_all
Stem.delete_all
StemJoin.delete_all

# This creates a lot of Things with actual English sentences for full text search testing
Rails.root.join("db/contents.txt").each_line do |line|
  Thing.create content: line.chomp
end