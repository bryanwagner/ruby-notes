require File.expand_path(File.dirname(__FILE__) + '/neo')

# You need to write the triangle method in the file 'triangle.rb'
require './triangle.rb'

class AboutTriangleProject2 < Neo::Koan

  def triangle(a, b, c)
    sides = [a, b, c].sort
    raise TriangleError if sides[0] <= 0 || sides[2] * sides[2] != sides[1] * sides[1] + sides[0] * sides[0]
    equalPairs = (a == b ? 1 : 0) + (a == c ? 1 : 0) + (b == c ? 1 : 0)
    equalPairs == 3 ? :equilateral : (equalPairs == 1 ? :isosceles : :scalene)
  end

  # The first assignment did not talk about how to handle errors.
  # Let's handle that part now.
  def test_illegal_triangles_throw_exceptions
    assert_raise(TriangleError) do triangle(0, 0, 0) end
    assert_raise(TriangleError) do triangle(3, 4, -5) end
    assert_raise(TriangleError) do triangle(1, 1, 3) end
    assert_raise(TriangleError) do triangle(2, 4, 2) end
    # HINT: for tips, see http://stackoverflow.com/questions/3834203/ruby-koan-151-raising-exceptions
  end
end
