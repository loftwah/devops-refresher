# What Happens When You Visit `fm.loftwah.com`

## High-Level Story

1. You press enter in Chrome's address bar (Chrome calls it the "omnibox"). Chrome double-checks whether it already has a fresh copy of the page and whether it should immediately jump to HTTPS because of security lists like HSTS.
2. Your laptop turns `fm.loftwah.com` into one or more IP addresses. It walks through caches first, then asks DNS servers. If the name is really an alias (a CNAME) to a load balancer, the chain of lookups continues until the load balancer hands back the real IPs.
3. With an IP in hand, Chrome opens a TCP connection to port 443. That involves the three-way handshake (SYN, SYN-ACK, ACK) followed by the TLS handshake so everything stays encrypted.
4. Chrome sends the HTTPS request. A CDN or load balancer may answer straight away or forward the call to the application servers. The response streams back.
5. Chrome parses the HTML, runs the scripts, requests any extra files, and paints pixels on screen.

Each stage has variations - like cached vs uncached data, DNS over HTTPS vs classic UDP, or HTTP/3 over QUIC instead of TCP - but the big picture stays the same.

---

## Detailed Timeline

### 0. Getting Ready in the Browser

- **Address bar check:** Chrome looks at what you typed and decides it's a URL rather than a search. It also checks history, bookmarks, and security rules. If the site is preloaded for HTTPS, Chrome upgrades to `https://` before anything leaves the laptop.
- **Cache lookups:** The browser keeps a disk cache of recent responses. If it finds a fresh copy, it can render immediately. If the cached copy is expired but still usable, Chrome will send a conditional request later (`If-None-Match` or `If-Modified-Since`).
- **What if you only typed part of it?** Typing `fm` might trigger autocomplete or a search instead of a direct visit. Company devices might also require traffic to run through a proxy, so those rules are checked here too.

### 1. Finding an IP Address (DNS Resolution)

1. **Browser cache comes first.** Chrome keeps a small in-memory list of recent DNS answers for about a minute. A hit here skips the rest.
2. **Operating system cache next.** macOS or Windows hold answers based on their TTL (time to live). Commands like `sudo dscacheutil -flushcache` clear that cache when you need a fresh lookup.
3. **Hosts file override.** Entries in `/etc/hosts` (or `C:\Windows\System32\drivers\etc\hosts`) take priority. This is handy for pointing `fm.loftwah.com` to a test server.
4. **Ask the configured resolver.** When caches miss, the OS sends a DNS query, usually UDP on port 53, to whatever resolver the network configuration provides (perhaps the router, 1.1.1.1, 8.8.8.8, or an internal server). Some setups use DNS over HTTPS (DoH) or DNS over TLS (DoT), which wraps the question inside HTTPS or TLS to prevent snooping.
5. **Resolver recursion.**

   - The resolver may need to ask a root name server, which replies with the `.com` servers.

   - The `.com` servers respond with the name servers for `loftwah.com`.

   - Those authoritative servers finally answer for `fm.loftwah.com`. If the record is a CNAME, the resolver follows that alias - perhaps `fm.loftwah.com` -> `fm-lb.loftwah.net` - and keeps going until it reaches A or AAAA records. Load balancers often return multiple IPs so clients can spread traffic.

6. **Cache all the things.** Every stop along the way caches the answer for the TTL so the next visit is quicker.

**Example command:**

```bash
dig +trace fm.loftwah.com
```

This shows the entire chain of questions the resolver asks, including any CNAME hops to load balancers.

### 2. Building the TCP Connection

Once the DNS answer produces an IP - say `198.51.100.42` for this example - Chrome dials TCP port 443.

1. **SYN:** The browser sends a packet with the SYN (synchronize) flag plus an initial sequence number. Think of it as "can we start talking, and here's where my numbering begins."
2. **SYN-ACK:** The server replies with both SYN and ACK flags. It acknowledges the browser's sequence number and shares its own starting number.
3. **ACK:** The browser sends back an ACK confirming the server's number. At this point both sides agree on numbering and the connection is live.

```
Client                        Server
SYN  (seq=100)  ------------>
               <------------  SYN,ACK (seq=500, ack=101)
ACK  (ack=501)  ------------>
```

- **Other possibilities:**
  - TCP Fast Open can include the first bytes of data with the SYN to save a round trip.
  - HTTP/3 uses QUIC instead, which rides on UDP and combines transport and TLS into a single handshake (usually one round trip, sometimes zero with resumption).
  - Corporate proxies may require a CONNECT tunnel, or firewalls might block non-standard ports and return a reset (RST).

### 3. Wrapping the Connection in TLS

Because the site uses HTTPS, the next step is to agree on encryption keys.

- **ClientHello:** Chrome proposes TLS 1.3, sends the list of supported cipher suites, and includes the Server Name Indication (SNI) so the server knows which certificate to present. It also offers ALPN values like `h2` (HTTP/2) and `http/1.1` so the server can pick the protocol.
- **ServerHello:** The server chooses the cipher, sends its certificate chain, and shares key exchange information (e.g., ECDHE parameters). Chrome validates the certificate against trusted authorities.
- **Key exchange:** Both parties create the shared secret and derive session keys using HKDF. TLS 1.3 is very fast here.
- **Finished messages:** They trade final "Finished" packets that prove both sides derived the same keys.

**Alternatives and optimizations:**

- If the site sits behind a CDN or load balancer, the TLS handshake may terminate there, and internal traffic between the load balancer and the app could be plain HTTP.
- TLS session tickets or session IDs allow resuming earlier connections, cutting a round trip. TLS 1.3 can even send 0-RTT data on resumption.
- If the server only supports HTTP/1.1, ALPN negotiates that; otherwise HTTP/2 offers multiplexed streams over the same connection.

### 4. Sending the HTTPS Request and Getting the Response

- **Request example:**

  ```http
  GET / HTTP/2
  Host: fm.loftwah.com
  User-Agent: Mozilla/5.0 ... Chrome/124.0
  Accept: text/html,application/xhtml+xml
  Accept-Encoding: br, gzip
  ```

- **Where it might go:**

  1. A **CDN edge** (Cloudflare, CloudFront, etc.) that already has the page cached.
  2. A **load balancer** that chooses the healthiest backend server and maybe rewrites headers.
  3. A **reverse proxy** such as Nginx or Envoy that handles gzip, auth, or routing to the right service.
  4. The **application** code, which might read from databases or other APIs before returning HTML or JSON.

- **Typical responses:** `200 OK` with HTML, `304 Not Modified` if the asset is unchanged, or redirects (`301`/`302`) if the canonical host is different. Errors like `503 Service Unavailable` happen when maintenance or outages occur.

- **Variations:** Server-side rendering might deliver a complete page up front. Single-page apps may send a skeleton page and rely on JavaScript to fetch data after load. HTTP headers (`Cache-Control`, `Set-Cookie`, `Strict-Transport-Security`) tell the browser what to do next time.

### 5. Rendering the Page

1. **Parse HTML:** Chrome builds the DOM tree. Blocking `<script>` tags pause parsing unless they use `async` or `defer`.
2. **Process CSS:** CSS files turn into the CSSOM. Combining DOM + CSSOM produces the render tree used for layout.
3. **Layout and paint:** Chrome calculates sizes and positions, rasterizes layers, and paints them to the screen.
4. **Run JavaScript:** V8 executes scripts, schedules work, and may call APIs or fetch more data.
5. **Load sub-resources:** Images, fonts, CSS, and JS trigger more requests. Under HTTP/2 the browser can reuse the same connection with separate streams.

- **Bonus behaviors:** Progressive Web Apps might claim a Service Worker, which can intercept future requests and serve cached responses immediately. Preload and preconnect hints help warm up connections before they're needed.

### 6. After the First Paint

- **State and storage:** `Set-Cookie` headers store session info; scripts may write to `localStorage` or `IndexedDB`.
- **Security rules:** Content Security Policy (CSP), HSTS, and SameSite cookie flags are enforced to guard against common attacks.
- **Ongoing connections:** Analytics scripts can send beacons. If the app opens a WebSocket, it performs an HTTP upgrade and keeps that connection alive.
- **Caching for later:** Assets eligible for caching land in Chrome's disk cache. Service Workers may keep their own caches to make repeat visits nearly instant.

---

## Critical Points to Remember

- DNS resolution is layer upon layer of caches before the resolver ever hits the authoritative servers. Aliases (CNAMEs) often hide load balancers that return multiple IPs for resiliency.
- The TCP handshake is always SYN -> SYN-ACK -> ACK. It establishes reliable sequence numbers so the transport layer can reorder or retransmit as needed.
- TLS 1.3 keeps the handshake short - usually one extra round trip - and ALPN decides whether the conversation uses HTTP/2, HTTP/1.1, or, if both sides support it, HTTP/3 over QUIC.
- CDNs and load balancers make the "server" step dynamic. They can serve cached pages, choose the closest region, or shield origin servers completely.
- Once the first byte arrives, Chrome's rendering pipeline runs in stages - parse, style, layout, paint, execute scripts - all of which can affect perceived performance.
- HTTP/3 changes the transport but not the big picture: you still resolve the name, negotiate encryption, request content, and render it.

---

## Interview-Style Answer (2-3 Minutes)

"When I punch `fm.loftwah.com` into Chrome and hit enter, the browser first checks whether it already has a good copy of the page and whether security rules like HSTS say it must use HTTPS. If it needs the network, my laptop tries to turn the name into an IP - working through browser and OS caches, then the DNS resolver. If the record is an alias to a load balancer, the resolver follows that chain until it gets real IP addresses and usually ends up with a couple of options for redundancy.

With that IP, Chrome opens a TCP connection using the classic three-way handshake (SYN, SYN-ACK, ACK) and immediately wraps it in TLS 1.3 so the conversation is encrypted. Once that's done, the browser sends an HTTP request. A CDN or load balancer might answer straight away, or it forwards the request to the app servers. The response streams back, and Chrome starts parsing HTML, applying CSS, running scripts, and fetching images until the page is painted.

The whole thing often takes only a few hundred milliseconds when caches are warm, and the same flow works whether we're on raw TCP or newer options like HTTP/3 over QUIC - the steps just get combined to save round trips."

If the interviewer digs deeper, call out extras like DNS over HTTPS vs traditional DNS, how caching and conditional requests reduce load, or what the SYN/SYN-ACK/ACK flags actually look like in packet captures.
