using DataFrames
using MAT

typealias FreqHz{T} SIUnits.SIQuantity{T,0,0,-1,0,0,0,0,0,0}


@doc md"""
Steady State Response.
This composite type contains the information for steady state response recordings and analysis.

### Fields

* data: contains the recorded data
* trigers: contains information about timing for creation of epochs
* system_codes: contains system information
* samplingrate: the sampling rate of the data
* modulationrate: the modulation rate of the stimulus
* reference_channel: the channel the data has been referenced to
* file_path and file_name: where the file was read in from
* channel_names: the names of the channels
* processing: dictionary type to store analysis
* header: additional information read from the file

### Processing Fields
The following standard names are used when saving data to the processing dictionary.

* Name: The identifier for the participant
* Side: Side of stimulation
* Carrier_Frequency: Carrier frequency of the stimulus
* Amplitude: Amplitude of the stimulus
* epochs: The epochs extracted from the recording
* sweeps: The extracted sweeps from the recording

""" ->
type SSR
    data::Array
    triggers::Dict
    system_codes::Dict
    samplingrate::FreqHz{Number}
    modulationrate::FreqHz{Number}
    reference_channel::Array{String}
    file_path::String
    file_name::String
    channel_names::Array{String}
    processing::Dict
    header::Dict
end


#######################################
#
# SSR info
#
#######################################

@doc md"""
Return the sampling rate of a steady state type.
If no type is provided, the sampling rate is returned as a floating point.

### Example

Return the sampling rate of a recording

```julia
    s = read_SSR(filename)
    samplingrate(s)
```
""" ->
samplingrate(t, s::SSR) = convert(t, float(s.samplingrate))
samplingrate(s::SSR) = samplingrate(FloatingPoint, s)


@doc md"""
Return the modulation rate of a steady state type.
If no type is provided, the modulation rate is returned as a floating point.

### Example

Return the modulation rate of a recording

```julia
    s = read_SSR(filename)
    modulationrate(s)
```
""" ->
modulationrate(t, s::SSR) = convert(t, float(s.modulationrate))
modulationrate(s::SSR) = modulationrate(FloatingPoint, s)


#######################################
#
# Show
#
#######################################

import Base.show
function Base.show(io::IO, a::SSR)
    time_length = round(size(a.data,1) / a.samplingrate / 60, 2)
    println(io, "SSR measurement of $time_length mins with $(size(a.data,2)) channels sampled at $(a.samplingrate)")
    println(io, "  Modulation frequency: $(a.modulationrate )")

    if haskey(a.processing, "Amplitude")
        println(io, "  Stimulation amplitude: $(a.processing["Amplitude"]) dB")
    end
    if haskey(a.processing, "Name")
        println(io, "  Participant name: $(a.processing["Name"] )")
    end
    if haskey(a.processing, "Side")
        println(io, "  Stimulation side: $(a.processing["Side"] )")
    end
    if haskey(a.processing, "Carrier_Frequency")
        println(io, "  Carrier frequency: $(a.processing["Carrier_Frequency"] ) Hz")
    end

end


#######################################
#
# Manipulate channels
#
#######################################

@doc md"""
Add a channel to the SSR type with specified channel names.

### Example

Add a channel called `Merged`

```julia
    s = read_SSR(filename)
    new_channel = mean(s.data, 2)
    s = add_channel(s, new_channel, "Merged")
```
""" ->
function add_channel(a::SSR, data::Array, chanLabels::ASCIIString; kwargs...)

    info("Adding channel $chanLabels")

    a.data = hcat(a.data, data)
    push!(a.channel_names, chanLabels)

    return a
end


@doc md"""
Remove specified channels from SSR.

### Example

Remove channel Cz and those in the set called `EEG_Vanvooren_2014_Right`

```julia
a = read_SSR(filename)
    remove_channel!(a, [EEG_Vanvooren_2014_Right, "Cz"])
```
""" ->
function remove_channel!(a::SSR, channel_names::Array{ASCIIString}; kwargs...)
    remove_channel!(a, int([findfirst(a.channel_names, c) for c=channel_names]))
    info("Removing channel(s) $(append_strings(channel_names))"); end

function remove_channel!(a::SSR, channel_idx::Array{Int}; kwargs...)

    channel_idx = channel_idx[channel_idx .!= 0]

    info("Removing channel(s) $channel_idx")

    keep_idx = [1:size(a.data)[end]; ]
    for c = sort(channel_idx, rev=true)
        try
            splice!(keep_idx, c)
        end
    end

    a.data = a.data[:, keep_idx]

    a.channel_names = a.channel_names[keep_idx]

    return a
end

function remove_channel!(a::SSR, channel_names::Union(Array{String}); kwargs...)
    remove_channel!(a, convert(Array{ASCIIString}, channel_names)); end

function remove_channel!(a::SSR, channel_name::Union(Int, String, ASCIIString); kwargs...)
    remove_channel!(a, [channel_name]); end


@doc md"""
Remove all channels except those requested from SSR.

### Example

Remove all channels except Cz and those in the set called `EEG_Vanvooren_2014_Right`

```julia
a = read_SSR(filename)
    keep_channel!(a, [EEG_Vanvooren_2014_Right, "Cz"])

```
""" ->
function keep_channel!(a::SSR, channel_names::Array{ASCIIString}; kwargs...)
    info("Keeping channel(s) $(append_strings(channel_names))")
    keep_channel!(a, int([findfirst(a.channel_names, c) for c=channel_names]))
end


function keep_channel!(a::SSR, channel_idx::Array{Int}; kwargs...)

    remove_channels = [1:size(a.data,2); ]

    channel_idx = sort(channel_idx, rev=true)
    for c = channel_idx
        splice!(remove_channels, c)
    end

    remove_channel!(a, remove_channels; kwargs...)
end


#######################################
#
# Trim channels
#
#######################################

@doc md"""
Trim SSR recording by removing data after `stop` specifed samples.

### Optional Parameters

* `start` Remove samples before this value

### Example

Remove the first 8192 samples and everything after 8192*300 samples

```julia
s = trim_channel(s, 8192*300, start=8192)
```

""" ->
function trim_channel(a::SSR, stop::Int; start::Int=1, kwargs...)

    info("Trimming $(size(a.data)[end]) channels between $start and $stop")

    a.data = a.data[start:stop,:]

    a.triggers["Index"] -= (start-1)
    to_keep = find(a.triggers["Index"] .<= stop)
    a.triggers["Index"]        = a.triggers["Index"][to_keep]
    a.triggers["Duration"]     = a.triggers["Duration"][to_keep]
    a.triggers["Code"]         = a.triggers["Code"][to_keep]

    a.system_codes["Index"] -= (start-1)
    to_keep = find(a.system_codes["Index"] .<= stop)
    a.system_codes["Index"]    = a.system_codes["Index"][to_keep]
    a.system_codes["Duration"] = a.system_codes["Duration"][to_keep]
    a.system_codes["Code"]     = a.system_codes["Code"][to_keep]

    return a
end


#######################################
#
# Merge channels
#
#######################################

@doc md"""
Merge SSR channels listed in `merge_Chans` and label the averaged channel as `new_name`

### Example

```julia
    s = merge_channels(s, ["P6", "P8"], "P68")
```

""" ->
function merge_channels(a::SSR, merge_Chans::Array{ASCIIString}, new_name::String; kwargs...)

    debug("Total origin channels: $(length(a.channel_names))")

    keep_idxs = [findfirst(a.channel_names, i) for i = merge_Chans]
    keep_idxs = int(keep_idxs)

    if sum(keep_idxs .== 0) > 0
        warn("Could not merge as these channels don't exist: $(append_strings(vec(merge_Chans[keep_idxs .== 0])))")
        keep_idxs = keep_idxs[keep_idxs .> 0]
    end

    info("Merging channels $(append_strings(vec(a.channel_names[keep_idxs,:])))")
    debug("Merging channels $keep_idxs")

    a = add_channel(a, mean(a.data[:,keep_idxs], 2), new_name; kwargs...)
end

function merge_channels(a::SSR, merge_Chans::ASCIIString, new_name::String; kwargs...)
    a = merge_channels(a, [merge_Chans], new_name; kwargs...)
end


#######################################
#
# Helper functions
#
#######################################

function assr_frequency(rounded_freq::Number; stimulation_samplingrate::Number=32000,
                        stimulation_frames_per_epoch::Number=32768)

    round(rounded_freq/(stimulation_samplingrate / stimulation_frames_per_epoch)) *
                                                                stimulation_samplingrate / stimulation_frames_per_epoch
end

function assr_frequency(rounded_freq::AbstractVector)

    [assr_frequency(f) for f = rounded_freq]
end
