require_relative "../lib/massive"

docs = Massive.connect_as_docs("postgres://localhost/massive_rb")
class Customer
  attr_accessor :name, :email
  def initialize(name, email)
    @name = name 
    @email = email
  end
end
describe "Document queries" do
  before(:all) do
    docs.run("drop table if exists customers cascade;", [])
  end

  it "creates a table on save using a hash" do
    customer = docs.customers.save({name: "Dave", email: "dave@test.com"})
    expect(customer.id).to be > 0
    expect(customer.email).to eq("dave@test.com")
  end
  it "finds by id" do
    customer = docs.customers.find(1)
    expect(customer.id).to be > 0
  end
  it "returns everything" do
    customers = docs.customers.all
    expect(customers.length).to be > 0
  end
  it "updates if id exists" do
    customer = docs.customers.find(1)
    customer.friend = "Rob"
    res = docs.customers.save(customer)
    expect(res).to be_nil
  end
  it "finds by existence" do
    customer = docs.customers.filter(:email, "dave@test.com")
    expect(customer.id).to be > 0
  end
  it "finds by containment" do
    results = docs.customers.contains({email: "dave@test.com"})
    expect(results.length).to be > 0
  end
  it 'finds by straight up where' do
    results = docs.customers.where("(body ->> 'email') = $1", "dave@test.com")
    expect(results.length).to be > 0
  end
  it 'searches using tsvector' do
    results = docs.customers.search("dave")
    expect(results.length).to be > 0
  end

  it "deletes by id" do
    res = docs.customers.delete(1)
    expect(res).to be_nil
  end
  it "deletes by criteria" do
    docs.customers.save({name: "Pete", company: "Dwerft"})
    docs.customers.save({name: "Paula", company: "Dwerft"})
    res = docs.customers.delete_if({company: "Dwerft"})
    expect(res).to be_nil
  end
end
