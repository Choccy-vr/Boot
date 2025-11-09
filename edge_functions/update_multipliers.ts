import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Define CORS headers directly to be self-contained
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

console.log('Update Multipliers function starting up...');

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Get the winner and loser IDs from the request body
    const { winner_id, loser_id } = await req.json();
    if (!winner_id || !loser_id) {
      throw new Error('Missing winner_id or loser_id in the request body.');
    }

    // 2. Create a Supabase admin client to call the private database function
    const supabaseAdminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      // Pass the user's auth token to the database function so we can access auth.uid()
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );
    console.log('Supabase admin client created.');

    // 3. Call the private 'update_multipliers' function
    console.log(`Calling RPC to update multipliers for winner: ${winner_id}, loser: ${loser_id}`);
    const { error } = await supabaseAdminClient.rpc('update_multipliers', {
      winner_id,
      loser_id,
    });

    if (error) {
      // This will catch errors from the database function, like invalid IDs
      console.error('Error from update_multipliers RPC:', error.message);
      throw new Error(`Database update error: ${error.message}`);
    }

    console.log('Successfully updated multipliers.');
    // 4. Return a success response
    return new Response(JSON.stringify({ message: 'Multipliers updated successfully.' }), {
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