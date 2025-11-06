"""
structures.jl

Core data structures for profile analysis.
"""

using Dates

"""
    ProfileEntry

Profile entry representing a single function/location in the profile.
"""
struct ProfileEntry
    func::String
    file::String
    line::Int
    samples::Int
    percentage::Float64
end

"""
    ProfileData

Complete profile dataset with metadata.
"""
struct ProfileData
    timestamp::DateTime
    total_samples::Int
    entries::Vector{ProfileEntry}
    metadata::Dict{String, Any}
end
