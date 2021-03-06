type WordVectors{S<:AbstractString, T<:Real, H<:Integer}
    vocab::AbstractArray{S, 1} # vocabulary
    vectors::AbstractArray{T, 2} # the vectors computed from word2vec
    vocab_hash::Dict{S, H}    
end
function WordVectors{S, T}(vocab::AbstractArray{S,1}, 
                           vectors::AbstractArray{T,2})
    length(vocab) == size(vectors, 2) || 
        throw(DimensionMismatch("Dimension of vocab and vectors are inconsistent."))
    vocab_hash = Dict{S, Int}()
    for (i, word) in enumerate(vocab)
        vocab_hash[word] = i
    end
    WordVectors(vocab, vectors, vocab_hash)
end

function show{S,T}(io::IO, wv::WordVectors{S,T})
    len_vecs, num_words = size(wv.vectors)
    print(io, "WordVectors $(num_words) words, $(len_vecs)-element $(T) vectors")
end

"""
`vocabulary(wv)` 

Return all the vocabulary of the WordVectors `wv`.
"""
vocabulary(wv::WordVectors) = wv.vocab

"""
`in_vocabulary(wv, word)`

Return `true` if `word` is part of the vocabulary of `wv` and `false` otherwise.
"""
in_vocabulary(wv::WordVectors, word::AbstractString) = word in wv.vocab

"""
`size(wv)`

Return the size of the WordVectors `wv`. 
"""
size(wv::WordVectors) = size(wv.vectors)


"""
`index(wv, word)`

Return the index of `word` from the WordVectors `wv`.
"""
index(wv::WordVectors, word) = wv.vocab_hash[word]

"""
`get_vector(wv, word)`

Return the vector representation of `word` from the WordVectors `wv`. 
"""
get_vector(wv::WordVectors, word) = 
      (idx = wv.vocab_hash[word]; wv.vectors[:,idx])

"""
`cosine(wv, word, n=10)`

Return the position of `n` neighbors of `word` and cosine similarity 
"""
function cosine(wv::WordVectors, word, n=10)
    metrics = wv.vectors'*get_vector(wv, word)
    topn_positions = sortperm(metrics[:], rev = true)[1:n]
    topn_metrics = metrics[topn_positions]
    return topn_positions, topn_metrics
end


"""
`similarity(wv, word1, word2)`

Return the cosine similarity value between two words `word1` and `word2`.
"""
function similarity(wv::WordVectors, word1, word2)
    return get_vector(wv, word1)'*get_vector(wv, word2)
end


"""
`cosine_similar_words(wv, word, n=10)`

Return the top `n` most similar words to `word` from the WordVectors `wv`.
"""
function cosine_similar_words(wv::WordVectors, word, n=10)
    indx, metr = cosine(wv, word, n)
    return vocabulary(wv)[indx]
end


"""
`analogy(wv, pos, neg, n=5)`

Compute the analogy similarity between two lists of words. The positions
and the similarity values of the top `n` similar words will be returned. 
For example, 
`king - man + woman = queen` will be 
`pos=[\"king\", \"woman\"], neg=[\"man\"]`.
"""
function analogy(wv::WordVectors, pos::AbstractArray, neg::AbstractArray, n= 5)
    m, n_vocab = size(wv)
    n_pos = length(pos)
    n_neg = length(neg)
    anal_vecs = Array(AbstractFloat, m, n_pos + n_neg)
 
    for (i, word) in enumerate(pos)
        anal_vecs[:,i] = get_vector(wv, word)
    end
    for (i, word) in enumerate(neg)
        anal_vecs[:,i+n_pos] = -get_vector(wv, word)
    end
    mean_vec = mean(anal_vecs, 2)
    metrics = wv.vectors'*mean_vec
    top_positions = sortperm(metrics[:], rev = true)[1:n+n_pos+n_neg]
    for word in [pos;neg]
        idx = index(wv, word)
        loc = findfirst(top_positions, idx)
        if loc != 0
            splice!(top_positions, loc)
        end
    end
    topn_positions = top_positions[1:n]
    topn_metrics = metrics[topn_positions]
    return topn_positions, topn_metrics
end

"""
`analogy_words(wv, pos, neg, n=5)`

Return the top `n` words computed by analogy similarity between
positive words `pos` and negaive words `neg`. from the WordVectors `wv`. 
"""
function analogy_words(wv::WordVectors, pos, neg, n=5)
    indx, metr = analogy(wv, pos, neg, n)
    return vocabulary(wv)[indx]
end


"""
`wordvectors(fname [,type=Float64][; kind=:text])`

Generate a WordVectors type object from the file `fname`, where
`type` is the element of the vectors.
The file format can be either text (kind=`:text`) or 
binary (kind=`:binary`).
"""
function wordvectors{T<:Real}(fname::AbstractString, ::Type{T}; kind::Symbol=:text)
    if kind == :binary
				result
				try
        	return _from_binary(fname,T)
				catch e
				end
        return _from_binary2(fname,T)
    elseif kind == :text
        return _from_text(T, fname)
    else
        throw(ArgumentError("Unknown kind $(kind)"))
    end
end
wordvectors(frame::AbstractString; kind::Symbol=:text) = wordvectors(frame, Float64, kind = kind)

# generate a WordVectors object from binary file
function _from_binary{T <: Real}(filename::AbstractString, ::Type{T}) 
    open(filename) do f
        header = strip(readline(f))
        vocab_size,vector_size = map(x -> parse(Int, x), split(header, ' '))
        vocab = Array(AbstractString, vocab_size)
        #vectors = Array(Float32, vector_size, vocab_size)
        #binary_length = sizeof(Float32) * vector_size
        vectors = Array(T, vector_size, vocab_size)
        binary_length = sizeof(T) * vector_size
        for i in 1:vocab_size
            vocab[i] = strip(readuntil(f, ' '))
            #vector = reinterpret(Float32, readbytes(f, binary_length))
            vector = reinterpret(T, readbytes(f, binary_length))
            vec_norm = norm(vector)
            vectors[:, i] = vector./vec_norm  # unit vector
            readbytes(f, 1) # new line
        end
        return WordVectors(vocab, vectors) 
    end
end

function _from_binary2{T <: Real}(filename::AbstractString, ::Type{T}) 
    open(filename) do f
				vocab_size = read(f, Int32)  # "words"
				vector_size = read(f, Int32) # "size"
				println("vocab size: ", vocab_size)
				println("vector size: ", vector_size)
        #header = strip(readline(f))
        #vocab_size,vector_size = map(x -> parse(Int, x), split(header, ' '))
        vocab = Array(AbstractString, vocab_size) # "vocab"
        #vectors = Array(T, vector_size, vocab_size) # "M"
        vectors = spzeros(T, vector_size, vocab_size) # "M"
        binary_length = sizeof(T) * vector_size
				println("type : ", T)
        for i in 1:vocab_size
            vocab[i] = strip(readuntil(f, ' '))
            vector = reinterpret(T, readbytes(f, binary_length))
            vec_norm = norm(vector)
            vectors[:, i] = vector./vec_norm  # unit vector
            readbytes(f, 1) # new line
        end
        return WordVectors(vocab, vectors) 
    end
end


# generate a WordVectors object from text file
function _from_text{T}(::Type{T}, filename::AbstractString)
    open(filename) do f
        header = strip(readline(f))
        vocab_size,vector_size = map(x -> parse(Int, x), split(header, ' '))
        vocab = Array(AbstractString, vocab_size)
        vectors = Array(T, vector_size, vocab_size)
        @inbounds for (i, line) in enumerate(readlines(f))
            #println(line)
            line = strip(line)
            parts = split(line, ' ')
            word = parts[1]
            vector = map(x-> parse(T, x), parts[2:end])
            vec_norm = norm(vector)
            vocab[i] = word
            vectors[:, i] = vector./vec_norm  #unit vector
        end
       return WordVectors(vocab, vectors) 
    end    
end
