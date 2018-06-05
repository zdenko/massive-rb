# Massive.rb: A Postgres-centric Data Access Tool for Ruby

Massive.rb is a light-weight database utility for Ruby devoted to PostgreSQL. Massive doesn't compromise functionality in the name of database portability: you get all the power of PostgreSQL and it's amazing SQL capabilities, wrapped up in a convenient library.

Massive is _not_ an object-relational mapper (ORM)! There are no models, no change tracking; there's data in and data out - that's it. We try to do the 80% stuff, leaving the heavier, more challenging (and more fun!) queries for you to to by hand, with good old SQL.

A quick summary:

* **Dynamic query generation**: Massive uses `method_missing` to figure out which table you want to work with, then you add the criteria using a simple DSL.
* **FAST**: A super light bit of abstraction right on top of the PG driver. In addition, Massive supports prepared statements, which makes things even *faster* (see below).
* **Document storage**: PostgreSQL's JSONB storage type makes it possible to blend relational and document strategies. Massive offers a robust API to simplify working with documents: objects in, objects out, with document metadata managed for you.
* **Automatic Document Full Text Search**. Massive builds the document table for you, automatically applying a full text index to common field names, such as "name", "first", "last", "city" and so on. This will be configurable at some point.
* **Connection Pooling**. It's in there, and it works great. You can change it however you need as well.
* **100% PostgreSQL**: If you've worked with PostgreSQL, you probably love it. The project has been hailed as "the top software project out there" and is considered a pinnacle of software engineering. If you haven't used PostgreSQL before, you're in for a treat! This is why we don't abstract the functionality - this is one database you *want* to cuddle up to.

## A Simple Example

Massive has two ways to connect: *relational* or *document*. Let's do the relational bits first:

```ruby
db = Massive.connect("postgres://localhost/massive_rb")
user = db.users.find(1)
#user.id = 1
#user.email = 'test@test.com'
```

That's it. The API has 10 methods:

 * `insert` - adds a single record, taking a hash
 * `update` - updates a record
 * `delete` - yup, deletes a single record
 * `delete_where` - deletes a bunch
 * `all` - returns everything (with a 500 record cap)
 * `find` - finds by id
 * `filter` - filters by a hash criteria
 * `where` - plain where statement with params
 * `count` - returns a count of records
 * `count_where` - returns a count with a where statement

Let's see them in action:

```ruby
db = Massive.connect("postgres://localhost/massive_rb")

#insert a record
user =  db.users.insert({name: "Pete", email: "test@test.com"})

#pull back out
users = db.users.all 

#update it
user = db.users.update(1, {name: "Polly"})

#how many users do we have?
db.users.count 

#how many with the test.com domain? Let's use a Postgres regex
db.users.count_where("email ~ $1", "test.com")

#pull user 1
user = db.users.find(1)

#pull user by email
users = db.users.filter({company: "GitHub"}) #errr... Microsoft

#the "I DON'T WANT TO DEAL WITH YOUR DUMB DSL" method
users = db.users.where("email ~ $1", "test.com")

#we're done here
db.users.delete(1)

#nuke it all, we're joining MS
db.users.delete_where("company ~ $1", "Github")
```

You can query a view, materialized view or table using this DSL.

## Prepared Statements as Methods

If you know the queries you want to run ahead of time, preload them for extra special speed! Here's an example:

```ruby
#front-load the queries using a hash
queries = {
  active_products: "select * from products where active=true;",
  products_by_name: "select * from products where name=$1;"
}

#pass to Massive in spin up
db = Massive.connect("postgres://localhost/massive_rb", queries: queries)

#execute by name, skipping the precompilation step, making things FAST
results = db.active_products
results = db.products_by_name("Stuff")
```

## Documents

My goal with this API is to provide a MongoDB experience within PostgreSQL. This is *awesome* for design-time, when you really just don't want to deal with migrations or other things - let the UX tell you what's needed, then pump the data into PostgreSQL. You can normalize things later!

The first thing to know is that the Document API **only works with Hash or OpenStruct**, it won't (as of now), serialize class instances. This is because I don't know how to convert those into JSON reliably.

The Document API has the following methods:

 * `create_document_table` - creates a document table ready for storage.
 * `save` - inserts or saves a document
 * `search` - runs a full text search over a document set
 * `filter` - finds a record by using the PostgreSQL existence operator. This is a very efficient query that flexes the GIN index (more below)
 * `contains` - finds records using the containment operator `@>`, which uses the GIN index and is very efficient
 * `all` - returns everything
 * `find` - finds a record by id
 * `delete` - yup, deletes a single record
 * `delete_if` - deletes based on a JSON match
 * `where` - plain where statement with params

PostgreSQL's document storage is incredibly fast, especially when you correctly use the indexing provided. You don't have to worry about that messy SQL, we've got you covered.

Let's wind up the API:

```ruby

#Connect to the doc storage
docs = Massive.connect_as_docs("postgres://localhost/massive_rb")

#save a customer and build the table for me on the fly!
#this will run create_document_table if the table doesn't exist
#and it will apply the GIN index to body, which is where everything is stored
customer = docs.customers.save({name: "Dave", email: "dave@test.com"})

#pull the customer out
#this query uses the row id, flexxing the primary key index and doesn't bother
#with querying the JSON
customer = docs.customers.find(1)

#pull them all out
customers = docs.customers.all

#update
customer = docs.customers.find(1)
#this field didn't exist before...
customer.friend = "Rob"
#but it does now! Love the flexible nature of document storage! With PostgreSQL it's all the better
res = docs.customers.save(customer)

#find by email, making sure to use the index
#this returns only one record
customer = docs.customers.filter(:email, "dave@test.com")

#find all customers from GitHub. This returns many records and also uses the GIN index
docs.customers.contains({company: "GitHub"})

#I don't want to deal with this DSL!
customers = docs.customers.where("(body ->> 'email') = $1", "dave@test.com")

#flex the built-in text search
customers = docs.customers.search("dave")

#we're done here
docs.customers.delete(1)

#burn it down...
docs.customers.delete_if({company: "GitHub"})
```

## What's In That Full Text Index?
Currently, I'm extracting this from a project I'm working on. So if a document is saved with any of these fields, they're automatically indexed:

 * name
 * email
 * first
 * first_name
 * last
 * last_name
 * description
 * title
 * city
 * state
 * address
 * street
 * company

This works for me, but might not work for you. You can change the list of fields you want to search by passing it in when you open the connection:

```ruby
docs2 = Massive.connect_as_docs("postgres://localhost/massive_rb", searchable_fields: ["monkey"])
docs2.monkies.save({monkey: "a little furry friend with sweet blue eyes", email: "test2@test.com"})
results = docs2.monkies.search("friend") #returns our monkey
```

## Is This Ready for Production?

I'm using it... so ... maybe? There's not a lot too this library, just a light shim over pure SQL. I feel confident using it in production for myself, if that matters.

