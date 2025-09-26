import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Define CORS headers directly to avoid import errors during deployment.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

console.log('Matchmaking function starting up...');

Deno.serve(async (req) => {
  // Handle CORS preflight requests.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // IMPORTANT: Create a Supabase client with the SERVICE_ROLE_KEY.
    // This gives the function admin privileges and allows it to call private functions.
    const supabaseAdminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } } // Don't persist session for server-side client
    );
    console.log('Supabase admin client created.');

    // Call the private 'matchmake' database function.
    console.log("Calling the 'matchmake' RPC function...");
    const { data, error } = await supabaseAdminClient.rpc('matchmake');

    if (error) {
      console.error('Error from matchmake RPC:', error.message);
      return new Response(JSON.stringify({ error: `Database matchmaking error: ${error.message}` }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    console.log('Matchmake function returned successfully with data.');
    // Return the JSON array of the two selected ships.
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (err) {
    console.error('An unexpected error occurred:', err.message);
    return new Response(JSON.stringify({ error: `Unexpected server error: ${err.message}` }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});