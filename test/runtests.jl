
using Pack
using Test
using Random

function packcycle(value, T = typeof(value), isequal = isequal)
  bytes = Pack.pack(value)
  uvalue = Pack.unpack(bytes, T)
  return isequal(value, uvalue) && all(bytes .== Pack.pack(uvalue))
end

@testset "Primitives" begin

  @testset "Nothing" begin
    @test packcycle(nothing)
  end

  @testset "Bool" begin
    @test packcycle(true)
    @test packcycle(false)
  end

  @testset "Integer" begin
    for v in [-100000000000, -1000, -100, -10, 0, 10, 100, 1000, 10000000000]
      @test packcycle(v)
    end
  end

  @testset "Float" begin
    for v in [rand(Float16), rand(Float32), rand(Float64)]
      @test packcycle(v)
    end
  end

  @testset "String" begin
    for v in [randstring(n) for n in (3, 16, 32, 100, 1000)]
      @test packcycle(v)
    end
  end

  @testset "Vector" begin
    for F in [Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64]
      @test packcycle(rand(F, 100))
    end
    for F in [Float16, Float32, Float64]
      @test packcycle(rand(F, 100))
    end
  end

  @testset "Tuple" begin
    @test packcycle((:this, :is, "a tuple", (:with, true, :numbers), 5))
  end

  @testset "NamedTuple" begin
    @test packcycle((a = "named", b = "tuple", length = 3, tup = (5, 4)))
  end
end

