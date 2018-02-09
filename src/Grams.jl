module Grams

# Depends on: FunctionalCollections.jl

using FunctionalCollections

export grams, scapes, map_scapes
export skipgrams, skipgrams_itr

const List = FunctionalCollections.AbstractList

"""
    grams(arr, n)

Return all `n`-grams in `arr`.
`n` must be positive, otherwise an error is thrown.

# Examples

```julia-repl
julia> grams([1,2,3], 2)
2-element Array{Array{Int64,1},1}:
 [1, 2]
 [2, 3]
```
"""
function grams(arr::A, n::Int) where {A <: AbstractArray}
    @assert n>0
    l = size(arr, 1)
    [ arr[i:(i+n-1)] for i=1:(l-n+1) ]
end

"""
    scapes(arr)

Return all `n`-grams in `arr` for `n=1:size(arr, 1)`.

# Examples

```julia-repl
julia> scapes([1,2,3])
3-element Array{Array{Array{Int64,1},1},1}:
 Array{Int64,1}[[1], [2], [3]]
 Array{Int64,1}[[1, 2], [2, 3]]
 Array{Int64,1}[[1, 2, 3]]
```
"""
scapes(arr::A) where {A <: AbstractArray} =
    [ grams(arr, n) for n=1:size(arr,1) ]

"""
    map_scapes(f, arr)

Map `f` over all `n`-grams in arr for `n=1:size(arr, 1)`.
"""
map_scapes(f::Function, arr::A) where {A <: AbstractArray} =
    [ map(f, grams(arr, n)) for n=1:size(arr,1) ]

# skip-grams
# ----------

"""
    skipgrams_general(itr, k, n, cost [, pred])

Returns all generalized `k`-skip-`n`-grams.

Instead of defining skips as index steps > 1, a general distance function can be supplied.
`k` is then an upper bound to the sum of all distances between consecutive elements in the gram.

The input needs to be monotonous with respect to the distance to a
previous element:

    ∀ i<j<l: dist(itr[i], itr[j]) ≤ dist(itr[i], itr[l])

From this we know that if the current element increases the skip cost of some
unfinished gram (prefix) to more than `k`,
then all following elements will increase the cost at least as much,
so we can discard the prefix.

The `input` should be an iterable and will be consumed lazily
as the skipgram iterator is consumed.

An optional predicate function can be provided to test potential neighbors in a skipgram.
By default, all input elements are allowed to be neighbors.

# Examples

```julia
function skipgrams(itr, k, n)
    cost(x, y) = y[1] - x[1] - 1
    grams = skipgrams_general(enumerate(itr), k, n, cost)
    map(sg -> map(x -> x[2], sg), grams)
end
```
"""
function skipgrams_general(itr, k::Float64, n::Int, cost::Function,
                           pred::Function = ((x1, x2) -> true);
                           element_type = eltype(itr))
    # helpers
    mk_prefix(x) = (n-1, 0.0, plist{element_type}([x]))
    total_cost(pfx, x) = pfx[2] + cost(first(pfx[3]), x)
    extend_prefix(pfx, x) = (pfx[1]-1, total_cost(pfx, x), cons(x,pfx[3]))
    prefix_complete(pfx) = pfx[1] <= 0
    prefix_to_gram(pfx) = reverse!(collect(pfx[3]))

    # initial values (like ugly, mutable accumulators)
    prefixes = Vector{Tuple{Int,Float64,PersistentList{element_type}}}()
    found_grams = Vector{Vector{element_type}}()
    
    # generate candidates
    for candidate in itr
        # remove prefixes that cannot be completed anymore
        old_closed = filter(p -> total_cost(p, candidate) <= k, prefixes)

        # check for compatibility with candidate
        extendable = filter(p -> pred(first(p[3]), candidate), old_closed)
        
        # extend prefixes
        extended = map(p -> extend_prefix(p, candidate), extendable)

        # add complete prefixes to found
        append!(found_grams, map(prefix_to_gram,
                                 filter(prefix_complete, extended)))
        
        # add incomplete prefixes to prefixes
        prefixes = append!(old_closed, filter(!prefix_complete, extended))

        # open new prefix for candidate
        push!(prefixes, mk_prefix(candidate))
    end

    # return found skip grams
    found_grams
end

# skip-grams channel
# ------------------

function skipgrams_channel(itr, k::Float64, n::Int, cost::Function,
                           pred::Function = ((x1, x2) -> true))
    # helpers
    mk_prefix(x) = (n-1, 0.0, plist{eltype(itr)}([x]))
    total_cost(pfx, x) = pfx[2] + cost(first(pfx[3]), x)
    extend_prefix(pfx, x) = (pfx[1]-1, total_cost(pfx, x), cons(x,pfx[3]))
    prefix_complete(pfx) = pfx[1] <= 0
    prefix_to_gram(pfx) = reverse!(collect(pfx[3]))
    
    Channel() do c
        prefixes = []

        # generate candidates
        for candidate in itr
            # remove prefixes that cannot be completed anymore
            old_closed = filter(p -> total_cost(p, candidate) <= k, prefixes)

            # check for compatibility with candidate
            extendable = filter(p -> pred(first(p[3]), candidate), old_closed)

            # extend prefixes
            extended = map(p -> extend_prefix(p, candidate), extendable)
        
            # add incomplete prefixes to prefixes
            prefixes = append!(old_closed, filter(!prefix_complete, extended))
            
            # open new prefix for candidate
            push!(prefixes, mk_prefix(candidate))

            # add complete prefixes to found
            map(p -> put!(c, prefix_to_gram(p)), filter(prefix_complete, extended))
        end
    end
end

# skip-grams iterator
# -------------------

struct SkipGramItr{T}
    input
    k :: Float64
    n :: Int
    cost :: Function
    pred :: Function
end

const SGPrefix{T} = Tuple{Int, Float64, plist{T}}

struct SkipGramItrState{T,I}
    instate  :: I # state of input iterator
    prefixes :: Vector{SGPrefix{T}}    # list of prefixes
    out      :: Vector{Vector{T}} #List{Vector{T}} # found grams
    outstate :: Int
end

"""
    skipgrams_itr(input, k, n, cost, [pred], [element_type=type])

Returns an iterator over all generalized `k`-skip-`n`-grams found in `input`.

Instead of defining skips as index steps > 1, a general `cost` function is used.
`k` is then an upper bound to the sum of all distances between consecutive elements in the gram.

The input needs to be iterable and monotonous with respect to the cost to a
previous element:

    ∀ i<j<l: cost(input[i], input[j]) ≤ cost(input[i], input[l])

From this we know that if the current element increases the skip cost of some
unfinished gram (prefix) to more than `k`,
then all following elements will increase the cost at least as much,
so we can discard the prefix.

An optional predicate function can be provided to test potential neighbors in a skipgram.
By default, all input elements are allowed to be neighbors.

If `element_type` is provided, the resulting iterator will have a corresponding `eltype`.
If not, it will try to guess the element type based on the input's `eltype`.

# Examples

```julia
function skipgrams(itr, k, n)
    cost(x, y) = y[1] - x[1] - 1
    grams = skipgrams_itr(enumerate(itr), k, n, cost)
    map(sg -> map(x -> x[2], sg), grams)
end
```
"""
skipgrams_itr(itr, k::Float64, n::Int, cost::Function,
              pred::Function = ((x1, x2) -> true);
              element_type=eltype(itr)) =
    SkipGramItr{element_type}(itr, k, n, cost, pred)

## helpers for finding ngrams

function process_candidate(itr::SkipGramItr{T}, st::SkipGramItrState{T,I}) where {T, I}
    # define helpers
    mk_prefix(x) = (itr.n-1, 0.0, plist{T}([x]))
    total_cost(pfx, x) = pfx[2] + itr.cost(first(pfx[3]), x)
    extend_prefix(pfx, x) = (pfx[1]-1, total_cost(pfx, x), cons(x,pfx[3]))
    prefix_complete(pfx) = pfx[1] <= 0
    prefix_to_gram(pfx::SGPrefix{T}) :: Vector{T} = reverse!(collect(pfx[3]))

    # 1. generate candidates
    candidate, nextstate = next(itr.input, st.instate)

    # 2. remove prefixes that cannot be completed anymore
    old_closed = filter(p -> total_cost(p, candidate) <= itr.k, st.prefixes)

    # check for compatibility with candidate
    extendable = filter(p -> itr.pred(first(p[3]), candidate), old_closed)

    # 3. extend prefixes
    extended = map(p -> extend_prefix(p, candidate), extendable)

    # 4. collect completed grams
    # out = plist{Vector{T}}(map(prefix_to_gram, filter(prefix_complete, extended)))
    out = map(prefix_to_gram, filter(prefix_complete, extended))

    # 5. collect new prefixes
    # newpfx     = mk_prefix(candidate)
    # incomplete = filter(!prefix_complete, extended)
    # nextpfxs   = conj(old_closed ∪ incomplete, newpfx)
    nextpfxs = append!(old_closed, filter!(!prefix_complete, extended))
    push!(nextpfxs, mk_prefix(candidate))
    
    #...
    SkipGramItrState{T,I}(nextstate, nextpfxs, out, start(out))
end

new_grams(itr::SkipGramItr{T}, st::SkipGramItrState{T}) where T =
    if done(itr.input, st.instate)
        st
    else
        new = process_candidate(itr, st)
        if done(new.out, new.outstate)
            new_grams(itr, new)
        else
            new
        end
    end

## iterator interface

function Base.start(itr::SkipGramItr{T}) where T
    iout = Vector{Vector{T}}()
    init = SkipGramItrState(start(itr.input),
                            Vector{SGPrefix{T}}(), #pset{Tuple{Int, Float64, List{T}}}(),
                            iout, start(iout))
    new_grams(itr, init)
end

Base.done(itr::SkipGramItr, st::SkipGramItrState) =
    done(st.out, st.outstate)

function Base.next(itr::SkipGramItr{T}, st::SkipGramItrState{T,I}) where {T, I}
    gram, rest = next(st.out, st.outstate)
    nextst = SkipGramItrState{T,I}(st.instate, st.prefixes, st.out, rest)
    if done(st.out, rest) # queue empty now? generate new grams
        gram, new_grams(itr, nextst)
    else # not empty? dequeue
        gram, nextst
    end
end

Base.iteratorsize(itr::SkipGramItr) = Base.SizeUnknown()

Base.iteratoreltype(itr::SkipGramItr) = Base.HasEltype()

Base.eltype(itr::SkipGramItr{T}) where T = Vector{T}

# standard skipgrams
# ------------------

index_cost(x::Tuple{Int,T}, y::Tuple{Int,U}) where {T, U} = Float64(y[1] - x[1] - 1)

function skipgramsv(itr, k::Int, n::Int)
    map(sg -> map(x -> x[2], sg),
        skipgrams_general(enumerate(itr), # index is used for cost
                          Float64(k), n,  # as usual
                          index_cost))    # dist: more than "step" wrt indices
end

# skipgram iterator test
"""
    skipgrams(itr, k, n)

Return all `k`-skip-`n`-grams over `itr`, with skips based on indices.
For a custom cost function, use [`skipgrams_itr`](@ref).

# Examples

```julia-repl
julia> skipgrams([1,2,3,4,5], 2, 2)
9-element Array{Any,1}:
 Any[1, 2]
 Any[1, 3]
 Any[2, 3]
 Any[1, 4]
 Any[2, 4]
 Any[3, 4]
 Any[2, 5]
 Any[3, 5]
 Any[4, 5]
```
"""
function skipgrams(itr, k::Int, n::Int)
    map(sg -> map(x -> x[2], sg),
        skipgrams_itr(enumerate(itr), # index is used for cost
                      Float64(k), n,  # as usual
                      index_cost))    # dist: more than "step" wrt indices
end

# skipgram channel test
function skipgramsc(itr, k::Int, n::Int)
    map(sg -> map(x -> x[2], sg),
        skipgrams_channel(enumerate(itr), # index is used for cost
                      Float64(k), n,  # as usual
                      index_cost))    # dist: more than "step" wrt indices
end

end # module

