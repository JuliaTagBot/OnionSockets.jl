using OnionSockets

using CryptoGroups
using DiffieHellman
using Random
using Sockets
import Multiplexers: Multiplexer, route, forward

G = CryptoGroups.MODP160Group()
chash(envelopeA,envelopeB,key) = hash("$envelopeA $envelopeB $key")
dh = DH(data->(data,nothing),envelope->envelope,G,chash,() -> rand(1:BigInt(1)<<100))

ballotmember = dh
memberballot = dh
ballotgate = dh
gateballot = dh
membergate = dh
gatemember = dh

N = 2

@sync begin
    @async let
        routers = listen(2001)
        try
            @show "Router"
            serversocket = accept(routers)
            secureserversocket = accept(serversocket,nothing,ballotgate)

            mux = Multiplexer(secureserversocket,N) # Perhaps I could put route process with in mux.
            task = @async route(mux)

            susersockets = []
            for i in 1:N
                securesocket = accept(mux.lines[i],ballotmember)
                push!(susersockets,securesocket)
            end

            for i in 1:N
                serialize(susersockets[i],"A secure message from the router")
                @show deserialize(susersockets[i])
            end
            
            serialize(secureserversocket,:Terminate)
            wait(task)
        finally
            close(routers)
        end
    end

    @async let
        server = listen(2000)
        try 
            @show "Server"
            
            routersocket = connect(2001)
            secureballotbox = connect(routersocket,nothing,gateballot)

            usersockets = IO[]

            while length(usersockets)<N
                secureusersocket = accept(server,nothing,gatemember)
                push!(usersockets,secureusersocket)
            end

            forward(usersockets,secureballotbox)
        finally
            close(server)
        end
    end

    @async let
        @show "User 1"
        usersocket = connect(2000)
        securesocket = connect(usersocket,nothing,membergate)
        sroutersocket = connect(securesocket,nothing,memberballot)

        @show deserialize(sroutersocket)
        serialize(sroutersocket,"A scuere msg from user 1")
    end

    @async let
        @show "User 2"
        usersocket = connect(2000)
        securesocket = connect(usersocket,nothing,membergate)
        sroutersocket = connect(securesocket,nothing,memberballot)

        @show deserialize(sroutersocket)
        serialize(sroutersocket,"A scuere msg from user 2")
    end
end



