require_relative "../lib/massive"
db = Massive.connect("postgres://localhost/massive_rb")

describe "Massive Queries" do
  before(:all) do
    db.run("drop table if exists users cascade;")
    db.run("create table users(id serial primary key, name text, email text unique not null);")
  end
  it "inserts a simple record" do
    res = db.users.insert({name: "Pete", email: "test@test.com"})
    expect(res.id).to eq(1)
  end
  it "updates a simple record" do
    res = db.users.update(1, {name: "Polly"})
    expect(res.name).to eq("Polly")
  end
  it "does a count" do
    res = db.users.count 
    expect(res.count).to eq(1)
  end
  it "does a count where" do
    res = db.users.count_where("email ~ $1", "test.com")
    expect(res.count).to eq(1)
  end

  it "will find by id" do
    res = db.users.find(1)
    expect(res.id).to eq(1)
  end

  it "will filter by email" do
    res = db.users.filter({email: "test@test.com"})
    expect(res.length).to eq(1)
  end

  it "will execute where" do
    res = db.users.where("email ~ $1", "test.com")
    expect(res.length).to eq(1)
  end
  
  it "deletes a record by id" do
    res = db.users.delete(1)
    expect(res).to be_nil
  end
  it "deletes many records using where" do
    db.users.insert({name: "Bucky", email: "b@test.com"})
    db.users.insert({name: "Becky", email: "c@test.com"})
    res = db.users.delete_where("email ~ $1", "test.com")
    expect(res).to be_nil
  end

end