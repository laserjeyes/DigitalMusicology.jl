@testset "pitches" begin
    @test isbitstype(MidiPitch)
    @test hash(midi(12)) == hash(midi(12))

    @test midi(12) + midi(3) == midi(15)
    @test midi(2) - midi(3) == midi(-1)
    @test zero(midi(3)) == midi(0)
    @test zero(MidiPitch) == midi(0)

    @test pc(midi(12)) == midi(0)
    @test pc(midi(3)) == midi(3)
    @test pc(midi(-1)) == midi(11)
    @test pc(midi(-13)) == midi(11)

    @test transposeby(midi(3), midi(4)) == midi(7)
    @test transposeby(midi(3), midi(-4)) == midi(-1)
    @test transposeto(midi(8), midi(6)) == midi(6)
end

mutable struct spelledPitch
    accidentals :: Array{Int64}

    diatonic :: Vector{Int64}

    function spelledPitch()
        new(Array([
        [0,0,0,0,0,0,0],    # C/a
        [0,0,1,0,0,0,1],    # D/b
        [0,1,1,0,0,1,1],    # E/c#
        [0,0,0,-1,0,0,0],   # F/d
        [0,0,0,0,0,0,1],    # G/e
        [0,0,1,0,0,1,1],    # A/f#
        [0,1,1,0,1,1,1]]),  # B/g#
        Vector([1,2,3,4,5,6,7]))
    end
end

acc = [0 0 0 0 0 0 0; 0 0 1 0 0 0 1; 0 1 1 0 0 1 1; 0 0 0 -1 0 0 0; 0 0 0 0 0 0 1; 0 0 1 0 0 1 1; 0 1 1 0 1 1 1]
acc[:,1]
as = Major("Ab")
map(x -> getfield(x,:pc),as.pitches)
typeof((1,2))
collect(zip(diatonic,diatonic))
dia = -(0,1)
dia[1]
let x = 0
    x
end
x="Db"
length(x)
lowercase('#')

const b2, m2 = "1"
