# Custom MinHeap for SearchItem prioritization
#
# This replaces DataStructures.PriorityQueue which uses a Dict internally,
# requiring expensive hashing on every operation. Our custom MinHeap uses
# array-based storage for much better performance.

"""
    MinHeap{T}

A simple array-based min-heap for priority queue operations on SearchItem.

Much faster than DataStructures.PriorityQueue for our use case because:
- No hashing required (PriorityQueue uses Dict internally)
- Contiguous memory layout for better cache locality
- Simpler operations with less overhead

**Note**: This implementation is specialized for SearchItem and uses its d_min field
for ordering. The type parameter T is kept for consistency but is expected to be SearchItem.
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
    push!(h::MinHeap{T}, item::T) where T

Push an item onto the heap. Items must have isless defined.
For SearchItem, ordering is by d_min field.
"""
function Base.push!(h::MinHeap{T}, item::T) where T
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
Uses isless for comparison (for SearchItem, this compares d_min).
"""
function _percolate_up!(h::MinHeap{T}, i::Int) where T
    @inbounds item = h.data[i]

    while i > 1
        parent = i >> 1  # i ÷ 2
        @inbounds parent_item = h.data[parent]

        if !isless(item, parent_item)
            break
        end

        # Move parent down
        @inbounds h.data[i] = parent_item
        i = parent
    end

    @inbounds h.data[i] = item
end

"""
    popfirst!(h::MinHeap{T}) -> T

Remove and return the minimum element (highest priority).
"""
function Base.popfirst!(h::MinHeap{T}) where T
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
Uses isless for comparison (for SearchItem, this compares d_min).
"""
function _percolate_down!(h::MinHeap{T}, i::Int) where T
    @inbounds item = h.data[i]
    half_size = h.size >> 1  # h.size ÷ 2

    while i <= half_size
        # Find smallest child
        left = i << 1  # i * 2
        right = left + 1

        @inbounds left_item = h.data[left]

        # Determine which child to compare with
        child_item = left_item
        child = left
        if right <= h.size
            @inbounds right_item = h.data[right]
            if isless(right_item, left_item)
                child_item = right_item
                child = right
            end
        end

        # Check if we're done
        if !isless(child_item, item)
            break
        end

        # Move child up
        @inbounds h.data[i] = child_item
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
