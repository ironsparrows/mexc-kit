# ``MexcKitCore``

The models, requests, errors and domain protocols of MexcKit, without the client.

## Overview

Apps import `MexcKit`, which includes everything here and adds the client, `MexcFutures.Client`,
which implements every domain protocol. Import `MexcKitCore` alone in a module that only passes MEXC's
values around or mocks a domain, such as a ``MexcFutures/MarketAPI`` in tests, so it doesn't compile or
link the networking dependencies.
