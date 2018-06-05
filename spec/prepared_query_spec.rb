require_relative "../lib/massive"
queries = {
  active_products: "select * from products where active=true;",
  products_by_name: "select * from products where name=$1;"
}
db = Massive.connect("postgres://localhost/massive_rb", queries: queries)

describe "Prepared queries" do
  before(:all) do
    db.run("drop table if exists products;")
    db.run("create table products(id serial primary key, name text, active bool default true)")
    db.run("insert into products(name, active) values ('Stuff',true);")
  end
  it "will prepare a simple SQL statement if passed in" do
    expect{Massive.connect("postgres://localhost/massive_rb", queries: queries)}.not_to raise_error
  end
  it "will execute that prepared statement without params" do
    results = db.active_products
    expect(results.length).to be > 0
  end
  it "will execute a prepared statement with params" do
    results = db.products_by_name("Stuff")
    expect(results.length).to be > 0
  end
end