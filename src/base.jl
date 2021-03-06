
# ----------- TUPLES -------------
#
# Equality between tuples of float64 is defined at 10^-6 rouding error
≈(a::Tuple{Float64,Float64},b::Tuple{Float64,Float64};atol::Real=10^-6)=≈(a[1],b[1],atol=atol)&&≈(a[2],b[2],atol=atol)
≈(a::Array{Tuple{Float64,Float64}},b::Array{Tuple{Float64,Float64}};atol::Real=10^-6)=length(a)==length(b) ? all([x[1]≈x[2] for x in zip(a,b)]) : false

mutable struct Node <: StreamObject
    name::AbstractString
    presence::Intervals
end

# ----------- LINK DEFINITIONS -------------
#
mutable struct Link <: StreamObject
    name::AbstractString
    presence::Intervals
    from::AbstractString
    to::AbstractString
    weight::Float64
end

# --- Operations on StreamObjects ---
⊆(i::Intervals,o::StreamObject)=i ⊆ o.presence
⊆(i::Tuple{Float64,Float64},o::StreamObject)=i ⊆ o.presence
⊆(a::StreamObject,b::StreamObject)=a.presence ⊆ b.presence
∈(t::Float64,o::StreamObject)=t ∈ o.presence
∩(a::StreamObject,b::StreamObject)=a.presence ∩ b.presence
∪(a::StreamObject,b::StreamObject)=a.presence ∪ b.presence

# --- Operations on Nodes ---
function merge(n1::Node,n2::Node)
    if n1.name!=n2.name
        throw("Cannot merge nodes with different names...")
    end
    return Node(n1.name, n1 ∪ n2)
end

function merge!(n1::Node,n2::Node)
    if n1.name!=n2.name
        throw("Cannot merge nodes with different names...")
    end
    n1.presence = n1 ∪ n2
end

# --- Operations on Links ---
from_match(l1::Link,l2::Link)=(l1.from==l2.from)
from_match(name::AbstractString,l::Link)=(name==l.from)
to_match(l1::Link,l2::Link)=(l1.to==l2.to)
to_match(name::AbstractString,l::Link)=(name==l.to)
match(l1::Link,l2::Link)=from_match(l1,l2)&to_match(l1,l2)
match(from::AbstractString,to::AbstractString,l::Link)=from_match(from,l)&to_match(to,l)

function merge(l1::Link,l2::Link)
    if !match(l1,l2)
        throw("Cannot merge links with different end points...")
    end
    return Link(l1.name, l1 ∪ l2, l1.from, l1.to, l1.weight)
end

function merge!(l1::Link,l2::Link)
    if !match(l1,l2)
        throw("Cannot merge links with different end points...")
    end
    l1.presence = l1 ∪ l2
end

# --- Operations on Vectors of Nodes ---
get_idx(n::Node,a::Vector{Node})=findall(i->i==n,a)
get_idx(name::AbstractString,a::Vector{Node})=findall(i->i.name==name,a)
get_idx(t::Float64,a::Vector{Node})=findall(i->t ∈ i,a)

function ∪(a::Vector{Node},b::Vector{Node})
    c = Vector(Node[])
    for aa in a
        idx = get_idx(aa.name,b)
        if length(idx)==0
            new = Node(aa.name, aa.presence)
        elseif length(idx)==1
            new = Node(aa.name, aa ∪ b[idx][1])
        else
            throw("More than one node named $aa.name in array.")
        end
        push!(c,new)
    end
    for bb in b
        idx = get_idx(bb,a)
        if length(idx)==0
            new = Node(bb.name, bb.presence)
            push!(c,new)
        elseif length(idx)!=1
            throw("More than one node named $aa.name in array.")
        end
    end
    return c
end

function ∩(a::Vector{Node},b::Vector{Node})
    c = Vector(Node[])
    for aa in a
        idx = get_idx(aa.name,b)
        if length(idx)==1
            new = Node(aa.name, aa ∩ b[idx][1])
            push!(c,new)
        elseif length(idx)!=0
            throw("More than one node named $aa.name in array.")
        end
    end
    return c
end

# --- Operations on Vectors of Links ---
from_match(l1::Link,l::Vector{Link})=findall(x->from_match(x,l1),l)
from_match(name::AbstractString,l::Vector{Link})=findall(x->from_match(name,x),l)
to_match(l1::Link,l::Vector{Link})=findall(x->to_match(x,l1),l)
to_match(name::AbstractString,l::Vector{Link})=findall(x->to_match(name,x),l)
match(l1::Link,l::Vector{Link})=findall(x->match(x,l1),l)
match(from::AbstractString,to::AbstractString,l::Vector{Link})=findall(x->match(from,to,x),l)

get_idx(l::Link,a::Vector{Link})=findall(i->i==l,a)
get_idx(name::AbstractString,a::Vector{Link})=findall(i->i.name==name,a)
get_idx(t::Float64,a::Vector{Link})=findall(i->t ∈ i,a)

function ∪(a::Vector{Link},b::Vector{Link})
    c = Vector(Link[])
    for aa in a
        idx = match(aa,b)
        if length(idx)==0
            new = Link(aa.name, aa.presence, aa.from, aa.to, aa.weight)
        elseif length(idx)==1
            new = Link(aa.name, aa ∪ b[idx][1], aa.from, aa.to, aa.weight)
        else
            throw("More than one link matching from $aa.from and to $aa.to in array.")
        end
        push!(c,new)
    end
    for bb in b
        idx = match(bb,a)
        if length(idx)==0
            new = Link(bb.name, bb.presence, bb.from, bb.to, bb.weight)
            push!(c,new)
        elseif length(idx)!=1
            throw("More than one link matching from $aa.from and to $aa.to in array.")
        end
    end
    return c
end

function ∩(a::Vector{Link},b::Vector{Link})
    c = Vector(Link[])
    for aa in a
        idx = match(aa,b)
        if length(idx)==1
            new = Link(aa.name, aa ∩ b[idx][1], aa.from, aa.to, aa.weight)
            push!(c,new)
        elseif length(idx)!=0
            throw("More than one link matching from $aa.from and to $aa.to in array.")
        end
    end
    return c
end

# ----------- STREAM DEFINITIONS -------------
#
struct LinkStream <: AbstractUndirectedStream
    name::AbstractString
    T::Intervals
    V::Set{AbstractString}
    E::Dict{AbstractString,Dict{AbstractString,Link}}
end

struct DirectedLinkStream <: AbstractDirectedStream
    name::AbstractString
    T::Intervals
    V::Set{AbstractString}
    E::Dict{AbstractString,Dict{AbstractString,Link}}
end

#Base.getindex(ls::LinkStream, name::AbstractString)=haskey(ls.E,name) ? ls.E[name] : []
#Base.getindex(ls::LinkStream, t::Float64)=[l for (k,v) in ls.E for (kk,l) in v if t ∈ l]

struct StreamGraph <: AbstractUndirectedStream
    name::AbstractString
    T::Intervals
    V::Set{AbstractString}
    W::Dict{AbstractString,Node}
    E::Dict{AbstractString,Dict{AbstractString,Link}}
end

struct DirectedStreamGraph <: AbstractDirectedStream
    name::AbstractString
    T::Intervals
    V::Set{AbstractString}
    W::Dict{AbstractString,Node}
    E::Dict{AbstractString,Dict{AbstractString,Link}}
end

LinkStream(name::AbstractString) = LinkStream(name, Intervals([]), Set(), Dict())
LinkStream(name::AbstractString,T::Intervals) = LinkStream(name, T, Set(), Dict())

DirectedLinkStream(name::AbstractString) = DirectedLinkStream(name, Intervals([]), Set(), Dict())
DirectedLinkStream(name::AbstractString,T::Intervals) = DirectedLinkStream(name, T, Set(), Dict())

StreamGraph(name::AbstractString) = StreamGraph(name, Intervals([]), Set(), Dict(), Dict())
StreamGraph(name::AbstractString,T::Intervals) = StreamGraph(name, T, Set(), Dict(), Dict())

function neighborhood(s::AbstractUndirectedStream, node::AbstractString)
    N=Dict{AbstractString,Intervals}()
    for l in links(s,node)
        if l.from==node
            if haskey(N,l.to)
                N[l.to]=N[l.to] ∪ (times(s,l.to) ∩ l.presence)
            else
                N[l.to]=times(s,l.to) ∩ l.presence
            end
        elseif l.to==node
            if haskey(N,l.from)
                N[l.from]=N[l.from] ∪ (times(s,l.from) ∩ l.presence)
            else
                N[l.from]=times(s,l.from) ∩ l.presence
            end
        end
    end
    Dict{AbstractString,Node}([k=>Node(k,v) for (k,v) in N])
end

function neighborhood(s::AbstractUndirectedStream, node::AbstractString, t::Float64)
    neighbors=AbstractString[]
    for l in links(s,node)
        if t ∈ l
            if l.from==node
                push!(neighbors,l.to)
            elseif l.to==node
                push!(neighbors,l.from)
            end
        end
    end
    neighbors
end   

#Base.getindex(s::StreamGraph, name::AbstractString)=ls.W[name]
#Base.getindex(s::AbstractDirectedStream, from::AbstractString, to::AbstractString)=s.E[from][to]
#Base.getindex(s::AbstractUndirectedStream, from::AbstractString, to::AbstractString)=(haskey(s.E,from)&haskey(s.E[from],to)) ? s.E[from][to] : s.E[to][from]

# ----------- OPERATIONS ON STREAMS -------------
#
∈(t::Float64,s::AbstractStream)=t ∈ s.T
∈(n::Node,s::StreamGraph)=haskey(s.W,n.name) & s.W[n.name] == n
∈(n::Node,s::DirectedStreamGraph)=haskey(s.W,n.name) & s.W[n.name] == n
∈(l::Link,s::AbstractStream)=haskey(s.E,l.from) & haskey(s.E[l.from],l.to) & s.E[l.from][l.to] == l
∈(n::AbstractString,ls::Union{LinkStream,DirectedLinkStream})=n ∈ ls.V
∈(n::AbstractString,s::Union{StreamGraph,DirectedStreamGraph})=(n ∈ s.V) & haskey(s.W,n)

⊆(t::Tuple{Float64,Float64},s::AbstractStream)=t ⊆ s.T
# TO UPDATE -----
⊆(ls1::LinkStream,ls2::LinkStream)=(ls1.T ⊆ ls2.T)&(ls1.V ⊆ ls2.V)&(ls1.E ⊆ ls2.E)
⊆(s1::StreamGraph,s2::StreamGraph)=(s1.T ⊆ s2.T)&(s1.V ⊆ s2.V)&(s1.W ⊆ s2.W)&(s1.E ⊆ s2.E)

∩(ls1::LinkStream,ls2::LinkStream)=LinkStream("$ls1.name n $ls2.name", ls1.T ∩ ls2.T, ls1.V ∩ ls2.V, ls1.E ∩ ls2.E)
∩(s1::StreamGraph,s2::StreamGraph)=StreamGraph("$s1.name n $s2.name", s1.T ∩ s2.T, s1.V ∩ s2.V, s1.W ∩ s2.W, s1.E ∩ s2.E)

∪(ls1::LinkStream,ls2::LinkStream)=LinkStream("$ls1.name u $ls2.name", ls1.T ∪ ls2.T, ls1.V ∪ ls2.V, ls1.E ∪ ls2.E)
∪(s1::StreamGraph,s2::StreamGraph)=StreamGraph("$s1.name u $s2.name", s1.T ∪ s2.T, s1.V ∪ s2.V, s1.W ∪ s2.W, s1.E ∪ s2.E)
# -----

struct NodeEvent <: Event
    t::Float64
    arrive::Bool
    object::AbstractString
end

struct LinkEvent <: Event
    t::Float64
    arrive::Bool
    object::Tuple{AbstractString,AbstractString}
end

==(e1::Event,e2::Event)=(e1.t==e2.t)&(e1.arrive==e2.arrive)&(e1.object==e2.object)



# ----------- STATE -------------
#
mutable struct State
    t0::Float64
    t1::Float64
    nodes::Set{AbstractString}
    links::Set{Tuple{AbstractString,AbstractString}}
end

# ----------- TRANSITION -------------
#
mutable struct Transition
    tprev::Float64
    t::Float64
    tnxt::Float64
    node_arrivals::Set{AbstractString}
    node_departures::Set{AbstractString}
    link_arrivals::Set{Tuple{AbstractString,AbstractString}}
    link_departures::Set{Tuple{AbstractString,AbstractString}}
end

Δnodes(t::Transition)=length(t.node_arrivals)-length(t.node_departures)
Δlinks(t::Transition)=length(t.link_arrivals)-length(t.link_departures)

function apply!(s::State,τ::Transition)
    # Moving backward
    if s.t0 == τ.t
        s.t0=τ.tprev
        s.t1=τ.t
        length(τ.node_arrivals - s.nodes)>0 && throw("<Backward Move> Absent nodes cannot leave the state.")
        s.nodes=s.nodes - τ.node_arrivals
        length(s.nodes ∩ τ.node_departures)>0 && throw("<Backward Move> Nodes already present in state cannot arrive in Transition.")
        s.nodes=s.nodes ∪ τ.node_departures
        length(τ.link_arrivals - s.links)>0 && throw("<Backward Move> Absent links cannot leave the state.")
        s.links=s.links - τ.link_arrivals
        length(s.links ∩ τ.link_arrivals)>0 && throw("<Backward Move> Links already present in state cannot arrive in Transition.")
        s.links=s.links ∪ τ.link_departures
    # Moving forward
    elseif s.t1 == τ.t
        s.t0=τ.t
        s.t1=τ.tnxt
        length(τ.node_departures - s.nodes)>0 && throw("<Forward Move> Absent nodes cannot leave the state.")
        s.nodes=s.nodes - τ.node_departures
        length(s.nodes ∩ τ.node_arrivals)>0 && throw("<Forward Move> Nodes already present in state cannot arrive in Transition.")                
        s.nodes=s.nodes ∪ τ.node_arrivals
        length(τ.link_departures - s.links)>0 && throw("<Forward Move> Absent links cannot leave the state.")
        s.links=s.links - τ.link_departures
        length(s.links ∩ τ.link_arrivals)>0 && throw("<Forward Move> Links already present in state cannot arrive in Transition.")
        s.links=s.links ∪ τ.link_arrivals 
    else
        throw("Cannot apply transition to given state.")
    end
end

# ----------- TIME CURSOR -------------
#
mutable struct TimeCursor
    S::State
    T::Dict{Float64,Transition}
end

## Move the cursor in the Stream ##
next_transition(tc::TimeCursor)=haskey(tc.T,tc.S.t1) ? tc.T[tc.S.t1] : throw("No transition in TimeMap at t=$(tc.S.t1)")
previous_transition(tc::TimeCursor)=haskey(tc.T,tc.S.t0) ? tc.T[tc.S.t0] : throw("No transition in TimeMap at t=$(tc.S.t0)")
next!(tc::TimeCursor)=haskey(tc.T,tc.S.t1) && apply!(tc.S,next_transition(tc))
previous!(tc::TimeCursor)=haskey(tc.T,tc.S.t0) && apply!(tc.S,previous_transition(tc))

function goto!(tc::TimeCursor,t::Float64)
    while !(tc.S.t0 <= t < tc.S.t1)
        t >= tc.S.t1 ? next!(tc) : previous!(tc)
    end
end

function start!(tc::TimeCursor)
    while haskey(tc.T,tc.S.t0)
        previous!(tc)
    end
    next!(tc)
end

function end!(tc::TimeCursor)
    while haskey(tc.T,tc.S.t1)
        next!(tc)
    end
    previous!(tc)
end

function load!(tc::TimeCursor,events::Vector{Event})
    tprev::Float64=events[1].t-0.1
    t::Float64=events[1].t
    tc.S=State(tprev,t,Set(),Set())
    idx::Int64=1
    node_arrivals=Set{AbstractString}()
    node_departures=Set{AbstractString}()
    link_arrivals=Set{Tuple{AbstractString,AbstractString}}()
    link_departures=Set{Tuple{AbstractString,AbstractString}}()
    transitions=Transition[]
    while idx <= length(events)
        while (idx <= length(events)) && (events[idx].t==t)
            if typeof(events[idx])==NodeEvent
                if events[idx].arrive
                    push!(node_arrivals,events[idx].object)
                else
                    push!(node_departures,events[idx].object)
                end
            else
                if events[idx].arrive
                    push!(link_arrivals,events[idx].object)
                else
                    push!(link_departures,events[idx].object)
                end
            end
            idx += 1
        end
        if length(transitions)>0
            transitions[end].tnxt=t
        end
        push!(transitions,Transition(tprev,t,-1,deepcopy(node_arrivals),
                                                deepcopy(node_departures),
                                                deepcopy(link_arrivals),
                                                deepcopy(link_departures)))
        empty!(node_arrivals)
        empty!(node_departures)
        empty!(link_arrivals)
        empty!(link_departures)
        tprev=t
        if idx<=length(events)
            t=events[idx].t
        end
    end
    transitions[end].tnxt=t
    for τ in transitions
        tc.T[τ.t]=τ
    end
end

# ----------- JUMPS -------------
#
struct Jump
    t::Float64
    from::AbstractString
    to::AbstractString
end

struct DurationJump
    t::Float64
    from::AbstractString
    to::AbstractString
    δ::Float64
end

# ----------- PATHS -------------
#
mutable struct Path <: AbstractPath
    jumps::Vector{Jump}
end

Path()=Path([])

mutable struct DurationPath <: AbstractPath
    jumps::Vector{DurationJump}
end

DurationPath()=DurationPath([])

start(p::AbstractPath)= length(p.jumps) > 0 ? p.jumps[1].t : 0
finish(p::Path)=length(p.jumps) > 0 ? p.jumps[end].t : 0
finish(p::DurationPath)=length(p.jumps) > 0 ? p.jumps[end].t + p.jumps[end].δ : 0

function is_valid(p::Path)
    if length(p)<=1
        return true
    end
    for cpt in zip(p.jumps[1:end-1],p.jumps[2:end])
        if cpt[1].t > cpt[2].t || cpt[1].to != cpt[2].from
            return false
        end
    end
    return true
end

function is_valid(p::DurationPath)
    if length(p)<=1
        return true
    end
    for cpt in zip(p.jumps[1:end-1],p.jumps[2:end])
        if cpt[1].t + cpt[1].δ > cpt[2].t || cpt[1].to != cpt[2].from
            return false
        end
    end
    return true
end

function +(p1::T,p2::T) where T <: AbstractPath
    if !is_valid(T([p1.jumps[end],p2.jumps[1]]))
        throw("Cannot concat paths.")
    end
    p = deepcopy(p1)
    for jump in p2.jumps
        push!(p.jumps,jump)
    end
    return p
end

function push(p::AbstractPath,jump::Jump)
    p2 = deepcopy(p)
    push!(p2.jumps,jump)
    if is_valid(p2)
        return p2
    else
        throw("Cannot add jump $jump to path because this will break the path feature.")
    end
end

function ⊆(p1::T,p2::T) where T <: AbstractPath
    lp1 = length(p1)
    lp2 = length(p2)
    if lp1 > lp2
        return false
    end
    for i in range(1,lp2-lp1)
        if p2.jumps[i:i+lp1-1] == p1.jumps
            return true
        end
    end
    return false
end