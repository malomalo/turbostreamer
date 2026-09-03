object false
cache :article_fragment

node(:author) do
  { name: $author.name, birthyear: $author.birthyear, bio: $author.bio }
end
node(:title) { "Profiling Jbuilder" }
node(:body)  { "How to profile Jbuilder" }
node(:date)  { $now }
node(:references) do
  $arr.map { |ref| { name: "Introduction to profiling", url: "http://example.com/" } }
end
node(:comments) do
  $arr.map do |ref|
    {
      author: { name: $author.name, birthyear: $author.birthyear, bio: $author.bio },
      email: "rolf@example.com",
      body: "Great article",
      date: $now,
    }
  end
end
