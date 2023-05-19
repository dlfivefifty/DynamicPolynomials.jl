import Base.==

#Base.iszero(t::Term) = iszero(MP.coefficient(t))
Base.iszero(p::Polynomial) = isempty(p)

# TODO This should be in Base with T instead of Variable{V,M}.
# See https://github.com/blegat/MultivariatePolynomials.jl/issues/3
function (==)(x::Vector{Variable{V,M}}, y::Vector{Variable{V,M}}) where {V,M}
    if length(x) != length(y)
        false
    else
        #for (xi, yi) in zip(x, y)
        for i in 1:length(x)
            if x[i] != y[i]
                return false
            end
        end
        true
    end
end

# Comparison of Variable

const AnyCommutative{O} = Union{Commutative{O},NonCommutative{O}}

function (==)(
    x::Variable{<:AnyCommutative{CreationOrder}},
    y::Variable{<:AnyCommutative{CreationOrder}},
)
    return x.variable_order.order.id == y.variable_order.order.id
end

function Base.isless(
    x::Variable{<:AnyCommutative{CreationOrder}},
    y::Variable{<:AnyCommutative{CreationOrder}},
)
    return isless(y.variable_order.order.id, x.variable_order.order.id)
end

# Comparison of Monomial

# graded lex ordering
function _exponents_compare(x::Vector{Int}, y::Vector{Int}, ::Type{MP.Graded{MP.LexOrder}})
    @assert length(x) == length(y)
    degx = sum(x)
    degy = sum(y)
    if degx != degy
        degx - degy
    else
        @inbounds for i in eachindex(x)
            if x[i] != y[i]
                return x[i] - y[i]
            end
        end
        return 0
    end
end

function MP.compare(x::Monomial{V,M}, y::Monomial{V,M}) where {V,M}
    return MP.compare(x, y, M)
end

function MP.compare(x::Monomial{V}, y::Monomial{V}, ::Type{MP.Graded{MP.LexOrder}}) where {V}
    degx = degree(x)
    degy = degree(y)
    if degx != degy
        return degx - degy
    else
        i = j = 1
        # since they have the same degree,
        # if we get j > nvariables(y), the rest in x.z should be zeros
        @inbounds while i <= nvariables(x) && j <= nvariables(y)
            if x.vars[i] > y.vars[j]
                if x.z[i] == 0
                    i += 1
                else
                    return 1
                end
            elseif x.vars[i] < y.vars[j]
                if y.z[j] == 0
                    j += 1
                else
                    return -1
                end
            elseif x.z[i] != y.z[j]
                return x.z[i] - y.z[j]
            else
                i += 1
                j += 1
            end
        end
        return 0
    end
end

function (==)(x::Monomial{V,M}, y::Monomial{V,M}) where {V,M}
    return MP.compare(x, y) == 0
end
(==)(x::Variable{V,M}, y::Monomial{V,M}) where {V,M} = convert(Monomial{V,M}, x) == y

# graded lex ordering
function Base.isless(x::Monomial{V,M}, y::Monomial{V,M}) where {V,M}
    return MP.compare(x, y) < 0
end
function Base.isless(x::Monomial{V,M}, y::Variable{V,M}) where {V,M}
    return isless(x, convert(Monomial{V,M}, y))
end
function Base.isless(x::Variable{V,M}, y::Monomial{V,M}) where {V,M}
    return isless(convert(Monomial{V,M}, x), y)
end

# Comparison of MonomialVector
function (==)(x::MonomialVector{V,M}, y::MonomialVector{V,M}) where {V,M}
    if length(x.Z) != length(y.Z)
        return false
    end
    allvars, maps = mergevars([MP.variables(x), MP.variables(y)])
    # Should be sorted in the same order since the non-common
    # polyvar should have exponent 0
    for (a, b) in zip(x.Z, y.Z)
        A = zeros(length(allvars))
        B = zeros(length(allvars))
        A[maps[1]] = a
        B[maps[2]] = b
        if A != B
            return false
        end
    end
    return true
end
(==)(mv::AbstractVector, x::MonomialVector) = monomial_vector(mv) == x
(==)(x::MonomialVector, mv::AbstractVector) = x == monomial_vector(mv)

# Comparison of Term
function (==)(p::Polynomial{V,M}, q::Polynomial{V,M}) where {V,M}
    # terms should be sorted and without zeros
    if length(p) != length(q)
        return false
    end
    for i in 1:length(p)
        if p.x[i] != q.x[i]
            # There should not be zero terms
            @assert p.a[i] != 0
            @assert q.a[i] != 0
            return false
        end
        if p.a[i] != q.a[i]
            return false
        end
    end
    return true
end

function _exponents_isless(x::Vector{Int}, y::Vector{Int}, ::Type{MP.Graded{MP.LexOrder}})
    @assert length(x) == length(y)
    degx = sum(x)
    degy = sum(y)
    if degx != degy
        degx < degy
    else
        for (a, b) in zip(x, y)
            if a < b
                return true
            elseif a > b
                return false
            end
        end
        false
    end
end

function Base.isapprox(
    p::Polynomial{V,M,S},
    q::Polynomial{V,M,T};
    rtol::Real = Base.rtoldefault(S, T, 0),
    atol::Real = 0,
    ztol::Real = iszero(atol) ? Base.rtoldefault(S, T, 0) : atol,
) where {V,M,S,T}
    i = j = 1
    while i <= length(p.x) || j <= length(q.x)
        if i > length(p.x) || (j <= length(q.x) && q.x[j] < p.x[i])
            if !isapproxzero(q.a[j], ztol = ztol)
                return false
            end
            j += 1
        elseif j > length(q.x) || p.x[i] < q.x[j]
            if !isapproxzero(p.a[i], ztol = ztol)
                return false
            end
            i += 1
        else
            if !isapprox(p.a[i], q.a[j], rtol = rtol, atol = atol)
                return false
            end
            i += 1
            j += 1
        end
    end
    return true
end
