object false
cache :cached_fragment

node(:items) do
  (0..100).map do |i|
    {
      a: i,
      b: i,
      c: i,
      d: i,
      e: i,

      subitems: (0..100).map do |j|
        {
          f: i.to_s * j,
          g: i.to_s * j,
          h: i.to_s * j,
          i: i.to_s * j,
          j: i.to_s * j,
        }
      end
    }
  end
end
