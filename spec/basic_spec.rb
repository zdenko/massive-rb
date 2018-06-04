require_relative "../lib/massive"

describe "Massive basics" do
  let(:db){Massive.connect("postgres://localhost/massive_rb")}
  let(:docs){Massive.connect_as_docs("postgres://localhost/massive_rb")}
  it "connects to local postgres relationally" do
    expect(db).to_not be_nil
  end
  it "connects to local postgres documentwise" do
    expect(docs).to_not be_nil
  end
  it "runs a very simple query" do
    res = db.single("select now();", [])
    expect(res.now).to_not be_nil
  end

end
