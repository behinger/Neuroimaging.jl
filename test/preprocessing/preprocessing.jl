@testset "Preprocessing" begin

    fname = joinpath(dirname(@__FILE__), "..", "data", "test_Hz19.5-testing.bdf")
    s = read_SSR(fname)

    @testset "Triggers" begin

        @testset "Validation" begin

            validate_triggers(s.triggers)

            s1 = deepcopy(s)
            delete!(s1.triggers, "Index")
            @test_throws KeyError validate_triggers(s1.triggers)

            s1 = deepcopy(s)
            delete!(s1.triggers, "Code")
            @test_throws KeyError validate_triggers(s1.triggers)

            s1 = deepcopy(s)
            delete!(s1.triggers, "Duration")
            @test_throws KeyError validate_triggers(s1.triggers)

            s1 = deepcopy(s)
            s1.triggers["test"] = [1]
            @test_throws KeyError validate_triggers(s1.triggers)

            s1 = deepcopy(s)
            s1.triggers["Duration"] = s1.triggers["Duration"][1:4]
            @test_throws KeyError validate_triggers(s1.triggers)

            s1 = deepcopy(s)
            s1.triggers["Code"] = s1.triggers["Code"][1:4]
            @test_throws KeyError validate_triggers(s1.triggers)

        end
    end
end


@testset "Referencing" begin

    signals = [0 1 2] .* ones(5, 3)

    @testset "Remove template" begin

        signals = [0 1 2] .* ones(5, 3)
        template = vec(2 * ones(5))
        @test remove_template(signals, template) == [-2 -1 0] .* ones(5, 3)


    end
    @testset "Reference to channel" begin

        @test rereference(signals, 3) == [-2 -1 0] .* ones(5, 3)
        @test rereference(signals, "C2", ["C1", "C2", "C3"]) == [-1 0 1] .* ones(5, 3)

    end

    @testset "Reference to group of channels" begin

        @test rereference(signals, [1, 2, 3]) == [-1 0 1] .* ones(5, 3)
        @test rereference(signals, ["C2", "C1", "C3"], ["C1", "C2", "C3"]) ==
              [-1 0 1] .* ones(5, 3)
        @test rereference(signals, "car", ["C1", "C2", "C3"]) == [-1 0 1] .* ones(5, 3)
        @test rereference(signals, "average", ["C1", "C2", "C3"]) == [-1 0 1] .* ones(5, 3)

    end
end

@testset "Filter" begin
    using DSP
    s = sin.(0:0.1:10*π)
	designmethod = FIRWindow(DSP.hamming(60+1))
    fs = 10.0
	responsetype = Highpass(2,fs=fs)
	fobj = digitalfilter(responsetype,designmethod)
    function generate_dummyeeg(data;fs=1.0u"Hz")
        return GeneralEEG(data,[],Dict(),Dict(),fs,[],"","",Dict(),Dict()) 
    end
    eeg = generate_dummyeeg(s,fs=10.0u"Hz")
    
    @testset "Custom Filter" begin
        @test all(Neuroimaging.filter(s,fobj,filtfilt=true) .<= 0.1)
        @test all(Neuroimaging.filter(s,fobj,filtfilt=false) .<= 0.1)
        @test all(Neuroimaging.filter(eeg,responsetype,designmethod).data .<= 0.1)
        
    end
    @testset "default window size" begin
        filterorder = Neuroimaging.default_fir_filterorder(responsetype,samplingrate(eeg))
        @test iseven(filterorder)
    end
end
