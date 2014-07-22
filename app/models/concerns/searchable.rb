module Searchable
  extend ActiveSupport::Concern

  included do
    class_attribute :searchable_columns_value
    has_many :stems, as: :searchable
    after_save :update_stems
  end

  def update_stems
    if self.searchable_columns_value.nil? || self.searchable_columns_value.empty?
      raise "Define searchable columns using #searchable_columns class method"
    end

    Stem.transaction do
      Stem.where(searchable_type: self.class.name, searchable_id: self.id)
          .delete_all

      words = self.attributes.symbolize_keys
              .values_at(*Array(self.searchable_columns_value))
              .flat_map { |value| DefaultWordBreaker.new(value).split }

      stems = []

      words.uniq.each do |word|
        stem = DefaultStemmer.stem(word)
        stems << Stem.new(searchable_type: self.class.name, searchable_id: self.id, word: stem)
      end

      Stem.import stems
    end
  end

  module ClassMethods
    def searchable_columns(*columns)
      self.searchable_columns_value = columns
    end

    def search(query, options = {})
      prepared_words = prepare_words(query)
      regulars   = prepared_words[:regular]
      inclusions = prepared_words[:included]
      exclusions = prepared_words[:excluded]

      sql = "id IN ("
      sql += "#{stems_query(regulars)}" if regulars.any?
      sql += " INTERSECT #{stems_query(inclusions)}" if inclusions.any?
      sql += " EXCEPT #{stems_query(exclusions)}" if exclusions.any?
      sql += ")"

      where(sql)
    end

    def prepare_words(query)
      words = query.split(/ +/)
      results = {
        regular: [],
        excluded: [],
        included: []
      }

      words.each do |word|
        case word.first
        when "-"
          results[:excluded] << DefaultStemmer.stem(word[1..-1])
        when "+"
          results[:included] << DefaultStemmer.stem(word[1..-1])
        else
          results[:regular] << DefaultStemmer.stem(word)
        end
      end

      results
    end

    def stems_query(words)
      Stem.select(:searchable_id)
          .where(searchable_type: 'Thing', word: words)
          .to_sql
    end
  end
end