#using DigitalMusicology
@enum Lang English German French Italian
const all_diatonics = Vector([1,2,3,4,5,6,7])
const diatonics_english = Dict(
    1 => "C",
    2 => "D",
    3 => "E",
    4 => "F",
    5 => "G",
    6 => "A",
    7 => "B",
    "C" => 1,
    "D" => 2,
    "E" => 3,
    "F" => 4,
    "G" => 5,
    "A" => 6,
    "B" => 7)
const diatonics2pc = Dict(
    1 => 0,
    2 => 2,
    3 => 4,
    4 => 5,
    5 => 7,
    6 => 9,
    7 => 11)
const all_accidentals = Array([
    [0,0,0,0,0,0,0],    # C/a
    [0,0,1,0,0,0,1],    # D/b
    [0,1,1,0,0,1,1],    # E/c#
    [0,0,0,-1,0,0,0],   # F/d
    [0,0,0,0,0,0,1],    # G/e
    [0,0,1,0,0,1,1],    # A/f#
    [0,1,1,0,1,1,1]])   # B/g#
const translate_accidental = Dict(
    -2 => "bb",
    -1 => "b",
    0 => "",
    1 => "#",
    2 => "##",
    3 => "###",
    "###" => 3,
    "##" => 2,
    "#" => 1,
    "" => 0,
    "b" => -1,
    "bb" => -2)

const pc2SP = Dict(
    0 => (1,0),
    1 => (2,-1),
    2 => (2,0),
    3 => (3,-1),
    4 => (3,0),
    5 => (4,0),
    6 => (5,-1),
    7 => (5,0),
    8 => (6,-1),
    9 => (6,0),
    10 => (7,-1),
    11 => (7,0))

struct pc # <: Pitch
    pc :: Int64
end

Base.show(io::IO, pitch::pc) = print(io,pitch.pc)

struct SP #<: Pitch
    pitch :: Tuple{Int64,Int64}
    english :: String
    pc :: pc

    SP(t::Tuple{Int64,Int64}) = new(t,SP2english(t),tuple2PC(t))
    function SP(str::AbstractString,::Val{English})
        let fstr = format_eng(str)
            let t = english2SP(fstr)
                new(t,fstr,tuple2PC(t))
            end
        end
    end

end

function SP2english(t::Tuple{Int64,Int64})
    d,a = t
    diatonics_english[d]*translate_accidental[a]
end

function english2SP(str::AbstractString)
    let d = diatonics_english[str[1:1]]
        length(str) > 1 ? (d,translate_accidental[str[2:end]]) : (d,0)
    end
end

format_eng(str::AbstractString) = length(str) > 1 ? uppercase(str[1:1])*lowercase(str[2:end]) : uppercase(str[1:1])

SP(str::AbstractString) = SP(str,Val{English}())
SP(i::Int64) = SP(pc2SP[i])
tuple2PC(t::Tuple{Int64,Int64}) = pc(mod(diatonics2pc[t[1]]+t[2],12))

function transposeby(sp::SP,interval::SP)
    ord,ora = sp.pitch
    ttd,tta = interval.pitch
    ttd = mod((ord-1)+(ttd-1),7)+1
    opc = sp.pc.pc
    ipc = interval.pc.pc
    tta += mod(opc+ipc,12)-tuple2PC((ttd,tta)).pc
    SP((ttd,tta))
end

#transposeby(SP("C#"),SP("G"))

SP(spv::Vector{Tuple{Int64,Int64}}) = map(SP,spv)





abstract type Scales #<: PitchCollections
end

mutable struct Major <: Scales

    diatonic :: Vector{Int64}
    accidentals :: Vector{Int64}
    pitches :: Vector{SP}
    pcs :: Vector{pc}

    function Major(d::Int64=1) # 1=C, 7=B
        dia = circshift(all_diatonics,-d+1)
        acc = all_accidentals[d]
        sps = SP(collect(zip(dia,acc)))
        pcs = map(x -> getfield(x,:pc),sps)
        new(dia,acc,sps,pcs)
    end
    function Major(t::Tuple{Int64,Int64})
        d,a = t
        stranspose!(Major(d),a)
    end
end

Major(pitch::pc) = Major(pc2SP[pitch.pc])
Major(s::SP) = Major(s.pitch)
#function Base.getproperty(s::Scales,::Val{:pcs})
#    neu = map(x -> getfield(x,:pc),s.pitches)
#    Core.setfield!(s, :pcs, neu)
#    println("Ja")
#    neu
#end


function update_pitches!(s::Scales)
     dia = s.diatonic
     acc = s.accidentals
     sps = SP(collect(zip(dia,acc)))
     Core.setfield!(s, :pitches, sps)
end

function Base.setproperty!(m::Scales,name::Symbol,neu::Vector{Int64})
    Core.setfield!(m, name, neu)
####Änderungern einfügen, wenn eine Eigenschaft neu zugewiesen wird
    #name == :accidentals && update_pitches!(m)
end

function stranspose!(s::Scales,semitones::Int64)
    s.accidentals += semitones * ones(Int64,7)
    s.pcs = map(x -> pc(mod(semitones+x.pc,12)),s.pcs)
    update_pitches!(s)
    s
end

stranspose(s::Scales,sp::SP) = transpose(s,sp.pitch)

function Base.in(pc::Int64,s::Scales)

end

function stranspose(s::Major,target=Tuple{Int64,Int64})
    Major(target)
end

Major(str::AbstractString) = Major(SP(str))

function Base.circshift(s::Scales,i::Int64)

    map(x -> vec(circshift(x,i)),(s.diatonic,s.accidentals,s.pitches,s.pcs))

end

struct Minor <: Scales

    diatonic :: Vector{Int64}
    accidentals :: Vector{Int64}
    pitches :: Vector{SP}
    pcs :: Vector{pc}

    function Minor(d::Int64=1)
        relative = transposeby(SP(d),SP(3))
        relative_scale = Major(relative)
        d,a,ps,pcs=circshift(relative_scale,2)
        new(d,a,ps,pcs)
    end
end

m = Minor("C")

function Base.getindex(s::Scales,i::Int64)
    s.pitches[i]
end

des = Major(pc(7))
des.pcs
stranspose(des,"Fb")

s = Major("Db")
s.accidentals += 0*ones(Int64,7)
c = SP("C")
diatonics_english["C"]
typeof(Array([[0,0,0,0,0,0,0],[0,0,1,0,0,0,1], [0,1,1,0,0,1,1], [0,0,0,-1,0,0,0], [0,0,0,0,0,0,1], [0,0,1,0,0,1,1], [0,1,1,0,1,1,1]]))

es = SP("F")
k2 = SP("Bb")
transposeby(es, k2)
