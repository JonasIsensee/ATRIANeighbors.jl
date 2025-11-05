# Custom MinHeap for SearchItem prioritization
#
# This replaces DataStructures.PriorityQueue which uses a Dict internally,
# requiring expensive hashing on every operation. Our custom MinHeap uses
# array-based storage for much better performance.

"""
    MinHeap{T}

A simple array-based min-heap for priority queue operations.

Much faster than DataStructures.PriorityQueue for our use case because:
- No hashing required (PriorityQueue uses Dict internally)
- Contiguous memory layout for better cache locality
- Simpler operations with less overhead
"""
mutable struct MinHeap{T}
    data::Vector{T}
    size::Int

    function MinHeap{T}(capacity::Int=64) where T
        new{T}(Vector{T}(undef, capacity), 0)
    end
end

"""
    Base.isempty(h::MinHeap)

Check if heap is empty.
"""
@inline Base.isempty(h::MinHeap) = h.size == 0

"""
    Base.length(h::MinHeap)

Get number of elements in heap.
"""
@inline Base.length(h::MinHeap) = h.size

"""
    _ensure_capacity!(h::MinHeap, min_capacity::Int)

Ensure heap has at least the specified capacity.
"""
@inline function _ensure_capacity!(h::MinHeap{T}, min_capacity::Int) where T
    if length(h.data) < min_capacity
        # Double the capacity
        new_capacity = max(min_capacity, length(h.data) * 2)
        resize!(h.data, new_capacity)
    end
end

"""
    push!(h::MinHeap{T}, item::T, priority::Float64) where T

Push an item onto the heap with given priority.
"""
function Base.push!(h::MinHeap{SearchItem}, item::SearchItem)
    # Resize if needed
    _ensure_capacity!(h, h.size + 1)

    # Add to end and bubble up
    h.size += 1
    @inbounds h.data[h.size] = item
    _percolate_up!(h, h.size)

    return h
end

"""
    _percolate_up!(h::MinHeap, i::Int)

Bubble element at index i up to maintain heap property.
Uses d_min as the priority (lower d_min = higher priority).
"""
function _percolate_up!(h::MinHeap{SearchItem}, i::Int)
    @inbounds item = h.data[i]
    priority = item.d_min

    while i > 1
        parent = i >> 1  # i ÷ 2
        @inbounds parent_priority = h.data[parent].d_min

        if priority >= parent_priority
            break
        end

        # Move parent down
        @inbounds h.data[i] = h.data[parent]
        i = parent
    end

    @inbounds h.data[i] = item
end

"""
    popfirst!(h::MinHeap{T}) -> T

Remove and return the minimum element (highest priority).
"""
function Base.popfirst!(h::MinHeap{SearchItem})
    if h.size == 0
        throw(ArgumentError("Heap is empty"))
    end

    @inbounds result = h.data[1]
    @inbounds h.data[1] = h.data[h.size]
    h.size -= 1

    if h.size > 0
        _percolate_down!(h, 1)
    end

    return result
end

"""
    _percolate_down!(h::MinHeap, i::Int)

Bubble element at index i down to maintain heap property.
Uses d_min as the priority (lower d_min = higher priority).
"""
function _percolate_down!(h::MinHeap{SearchItem}, i::Int)
    @inbounds item = h.data[i]
    priority = item.d_min
    half_size = h.size >> 1  # h.size ÷ 2

    while i <= half_size
        # Find smallest child
        left = i << 1  # i * 2
        right = left + 1

        @inbounds left_priority = h.data[left].d_min

        # Determine which child to compare with
        if right <= h.size
            @inbounds right_priority = h.data[right].d_min
            if right_priority < left_priority
                child = right
                child_priority = right_priority
            else
                child = left
                child_priority = left_priority
            end
        else
            child = left
            child_priority = left_priority
        end

        # Check if we're done
        if priority <= child_priority
            break
        end

        # Move child up
        @inbounds h.data[i] = h.data[child]
        i = child
    end

    @inbounds h.data[i] = item
end

"""
    clear!(h::MinHeap)

Remove all elements from the heap.
"""
function clear!(h::MinHeap)
    h.size = 0
    return h
end
