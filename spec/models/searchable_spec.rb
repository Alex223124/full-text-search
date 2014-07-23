class DummyThing < ActiveRecord::Base
  self.table_name = "things"
  include Searchable

  searchable_columns :content
end

describe Searchable do
  subject { DummyThing }

  describe ".included" do
    it "adds search configuration attributes" do
      expect(subject).to respond_to(:searchable_columns_value)
      expect(subject).to respond_to(:stemmer_value)
      expect(subject).to respond_to(:word_breaker_value)
    end

    it "adds has_many association for SearchDocument" do
      expect(subject.reflect_on_association(:search_documents).macro).to eq(:has_many)
    end

    it "sets word breaker and stemmer do defaults" do
      expect(subject.stemmer_value).to eq(DefaultStemmer)
      expect(subject.word_breaker_value).to eq(DefaultWordBreaker)
    end

    it "should call after_save :update_stems callback" do
      thing = subject.new(content: 'test')
      expect(thing).to receive(:update_stems)
      thing.save
    end
  end

  context "destroying searchable object" do
    it "removes all associated :search_documents" do
      thing = subject.create(content: 'test')
      expect(thing.search_documents.count).to eq(1)
      thing.destroy
      expect(thing.search_documents.count).to eq(0)
    end
  end

  describe "#update_stems" do
    context "creating new searchable object" do
      it "creates new search document with stems" do
        expect(SearchDocument.count).to eq(0)
        thing = subject.create(content: 'test running')
        expect(SearchDocument.count).to eq(1)
      end

      it "sets stems for the created SearchDocument" do
        thing = subject.create(content: 'test running')
        expect(thing.search_documents.first.stems).to eq(["test", "run"])
      end
    end

    context "updating existing searchable object" do
      it "changes only the stems column in associated SearchDocument" do
        thing = subject.create(content: 'test running')
        document = thing.search_documents.first
        expect(document.stems).to eq(["test", "run"])
        thing.update_attribute(:content, 'test flying')
        document.reload
        expect(document.stems).to eq(["test", "fly"])
      end
    end
  end

end