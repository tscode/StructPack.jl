
using StructPack
using Test
using Random
using Logging

function packcycle(
  value,
  T = typeof(value);
  isequal = isequal,
  fmt = DefaultFormat(),
  ctx = StructPack.DefaultContext(),
)
  bytes = pack(value, fmt, ctx)
  uvalue = unpack(bytes, T, fmt, ctx)
  return isequal(value, uvalue) && all(bytes .== pack(uvalue, fmt, ctx))
end

struct A
  a :: Nothing
  b :: String
  c :: Tuple{Int64, Float64}
  d :: Bool
end

A(c, d; b) = A(nothing, b, c, d)
A(; a = nothing, b, c, d) = A(a, b, c, d)

struct B
  a :: Int
  b :: Float64
  c :: String
end

struct C
  a :: Array
  b :: AbstractString
end

struct D end

@testset "AnyFormat" begin
  val = Dict(
    "a" => 5,
    "b" => [1., 2., 3.],
    "c" => true,
    false => "some text",
    nothing => -3,
  )
  bytes = pack(val)
  val2 = unpack(bytes)
  @test all(keys(val)) do key
    val[key] == val2[key]
  end
end

@testset "CoreFormats" begin

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

  @testset "Pair" begin
    @test packcycle((:this => 5, :is => 3, "a tuple" => "good"))
  end

  @testset "NamedTuple" begin
    @test packcycle((a = "named", b = "tuple", length = 3, tup = (5, 4)))
  end

end

@testset "BinArrays" begin
  for F in [Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64, Float16, Float32, Float64]
    for data in [rand(F, 5), rand(F, 1000)]
      for fmt in [VectorFormat(), BinVectorFormat(), ArrayFormat(), BinArrayFormat()]
        @test packcycle(data, fmt = fmt)
      end
    end
    for data in [rand(F, 5, 5), rand(F, 100, 100)]
      for fmt in [ArrayFormat(), BinArrayFormat()]
        @test packcycle(data, fmt = fmt)
      end
    end
  end
  for data in [BitArray(undef, 5, 5), BitArray(undef, 100, 100)]
    for fmt in [ArrayFormat(), BinArrayFormat()]
      @test packcycle(data, fmt = fmt)
    end
  end
end

@testset "StructFormats" begin
  val = A(nothing, "test", (10, 10.), false)

  for fmt in [MapFormat(), VectorFormat(), DynamicMapFormat(), StructFormat(), UnorderedStructFormat(), FlexibleStructFormat()]
    @test packcycle(val, fmt = fmt)
  end

  @test_throws ErrorException pack(val)

  StructPack.format(::Type{A}) = StructFormat()
  @test packcycle(val)

  # Specifically test flexible structs
  val2 = (f = 0, b = "test", d = false, c = (10, 10.), e = "irrelevant")
  bytes = pack(val2)
  for fmt in [MapFormat(), DynamicMapFormat(), DynamicVectorFormat(), StructFormat(), UnorderedStructFormat()]
    @test_throws StructPack.UnpackError unpack(bytes, A, fmt)
  end
  @test unpack(bytes, A, FlexibleStructFormat()) == val

  # Specifically test unordered structs
  val = B(5, 0., "test")
  bytes = pack((a = 5, c = "test", b = 0.))
  @test_throws StructPack.UnpackError unpack(bytes, B, StructFormat())
  @test val == unpack(bytes, B, UnorderedStructFormat())
end

@testset "Context" begin
  struct C1 <: StructPack.Context end
  StructPack.format(::Type{A}, ::C1) = VectorFormat()

  val = A(nothing, "test", (10, 10.), false)

  @test packcycle(val)
  @test packcycle(val, ctx = C1())
  @test length(pack(val, C1())) < length(pack(val))
  bytes = pack(val, C1())
  @test bytes == pack(val, ContextFormat{C1}())
  @test isequal(val, unpack(bytes, A, ContextFormat{C1}()))
end

@testset "Macro" begin
  struct C2 <: StructPack.Context end
  val = A(nothing, "test", (10, 10.), false)

  @test StructPack.fieldformats(A, C2()) == (DefaultFormat(), DefaultFormat(), DefaultFormat(), DefaultFormat())

  StructPack.@pack C2 A in UnorderedStructFormat A(c, d; b) [b in StringFormat]

  @test StructPack.format(A, C2()) == UnorderedStructFormat()
  @test StructPack.fieldformats(A, C2()) == (DefaultFormat(), DefaultFormat(), StringFormat())
  @test packcycle(val, ctx = C2())

  # Example from the documentation
  struct C3 <: StructPack.Context end
  struct P
    c::Float64
    b::Tuple{Int, Int}
    a::String
    d::Bool
  end

  cons(a, b, c) = P(c, (b, b), a, false)

  @pack C3 P in StructFormat cons(a, b::Int, c)

  bytes = pack((a = "testing", b = 5, c = 6.5))
  p = unpack(bytes, P, C3())
  @test cons("testing", 5, 6.5) == p
end

@testset "Macro2" begin
  struct Ctx1 <: StructPack.Context end

  # -------------------- #

  struct A0 end

  @pack A0 in NilFormat
  @test StructPack.format(A0) == NilFormat()

  @test packcycle(A0())

  # -------------------- #

  struct A1
    a::Int
  end

  @pack A1 in FloatFormat
  @pack Ctx1 A1 in SignedFormat

  @test StructPack.format(A1) == FloatFormat()
  @test StructPack.format(A1, Ctx1()) == SignedFormat()

  StructPack.destruct(v::A1, ::FloatFormat) = v.a
  StructPack.destruct(v::A1, ::SignedFormat, ::Ctx1) = v.a

  @test packcycle(A1(5))
  @test packcycle(A1(5), ctx = Ctx1())

  # -------------------- #

  struct A3
    a::A1
    b::String
  end

  A3(b::String; a::A1 = A1(5)) = A3(a, b)

  @pack A3 in StructFormat (b; a)

  @test packcycle(A3(A1(5), "test"))

  @test StructPack.format(A3) == StructFormat()
  @test StructPack.fieldnames(A3) == (:b, :a)
  @test StructPack.fieldtypes(A3) == (String, A1)
  @test StructPack.fieldformats(A3) == (DefaultFormat(), DefaultFormat())
  
  @pack Ctx1 A3 in UnorderedStructFormat (b::Float64; a) 

  @test StructPack.format(A3, Ctx1()) == UnorderedStructFormat()
  @test StructPack.fieldnames(A3, Ctx1()) == (:b, :a)
  @test StructPack.fieldtypes(A3, Ctx1()) == (Float64, A1)
  @test StructPack.fieldformats(A3, Ctx1()) == (DefaultFormat(), DefaultFormat())

  # -------------------- #

  struct A4
    a::A1
    b::String
  end

  b2(b, a) = A4(a, b)

  @pack A4 in StructFormat
  @pack A4 b2(b, a) [a in StructFormat]

  @test packcycle(A4(A1(5), "test"))
  @test StructPack.format(A4) == StructFormat()
  @test StructPack.fieldnames(A4) == (:b, :a)
  @test StructPack.fieldtypes(A4) == (String, A1)
  @test StructPack.fieldformats(A4) == (DefaultFormat(), StructFormat())

  # -------------------- #

  struct A5
    a::A1
    b::A1
  end

  a5val = A5(A1(5), A1(6))

  @pack A5 in StructFormat
  @test packcycle(a5val)
  l1 = length(pack(a5val))
  l3 = length(pack(a5val, Ctx1()))

  @pack A5 [a in DefaultFormat[Ctx1]]
  @test packcycle(a5val)
  l2 = length(pack(a5val))

  @test l1 > l2 > l3

  # -------------------- #

  struct A6{F, N}
    data::Array{F, N}
  end

  @pack {<: A6} in TypedFormat{StructFormat}
  @pack {<: A6} {::Type, ::Int}
  @pack {<: A6} [data in BinArrayFormat]
  @test packcycle(A6(rand(5, 5)), isequal = (a, b) -> a.data == b.data)

  @test StructPack.typeparamtypes(A6) == (Type, Int)
  @test StructPack.typeparamformats(A6) == (DefaultFormat(), DefaultFormat())
  @test StructPack.fieldformats(A6) == (BinArrayFormat(),)

  @pack Ctx1 {<: A6} {T::Type, I::Int} [T in TypeFormat, I in UnsignedFormat]
  @test packcycle(A6(rand(5, 5)), ctx = Ctx1(), isequal = (a, b) -> a.data == b.data)

  @test StructPack.typeparamtypes(A6, Ctx1()) == (Type, Int)
  @test StructPack.typeparamformats(A6, Ctx1()) == (TypeFormat(), UnsignedFormat())
  @test StructPack.fieldformats(A6, Ctx1()) == (BinArrayFormat(),)
end

@testset "TypedFormat" begin
  # This has to fail since no base format for D is specified
  StructPack.format(::Type{D}) = TypedFormat()
  with_logger(NullLogger()) do
    @test_throws StructPack.PackError pack(D())
  end
  # This, in contrast, has to work
  @test packcycle(D(), Any, fmt = TypedFormat{StructFormat}())

  # This has to fail since the type parameters of `Array` have not been typed
  val = rand(5, 5)
  @test_throws StructPack.PackError pack(val, TypedFormat())
  StructPack.typeparamtypes(::Type{<: Array}) = (Type, Int)
  @test packcycle(val, Array, fmt = TypedFormat())

  function Base.isequal(c1::C, c2::C)
    typeof(c1.a) == typeof(c2.a) && c1.a == c2.a && c1.b == c2.b
  end

  val = C(rand(2, 2), "This is a test")
  @test !packcycle(val, fmt = StructFormat())
  @test !packcycle(val, fmt = VectorFormat())
  StructPack.fieldformats(::Type{C}) = (TypedFormat(), TypedFormat())
  @test packcycle(val, fmt = StructFormat())
  @test !packcycle(val, fmt = VectorFormat())

  StructPack.valueformat(::Type{C}, index, ::VectorFormat) = TypedFormat()
  @test packcycle(val, fmt = StructFormat())
  @test packcycle(val, fmt = VectorFormat())
end

@testset "Extensions" begin
  for len in [1:10; 2^7; 2^8] 
    data = rand(UInt8, len)
    bytes = pack(data, ExtensionFormat{3}())
    ext = unpack(bytes, StructPack.AnyExtensionFormat())
    @test ext isa StructPack.ExtensionData
    @test ext.type == 3
    @test ext.data == data
  end
end

@testset "Skip" begin
  val = (
    (1, 2, 3),
    "test",
    (a = 5., b = "B"),
    true,
  )
  io = IOBuffer(pack(val))
  @test StructPack.step(io) == VectorFormat()
  @test unpack(io) == [1, 2, 3]
  StructPack.skip(io)
  @test StructPack.step(io) == MapFormat()
  StructPack.skip(io)
  StructPack.skip(io)
  @test unpack(io) == "b"
  @test unpack(io) == "B"
  @test unpack(io) == true
end
