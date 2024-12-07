-- Drop existing function
DROP FUNCTION IF EXISTS get_partner_stats(UUID);

-- Create improved partner stats function
CREATE OR REPLACE FUNCTION get_partner_stats(partner_id UUID)
RETURNS TABLE (
  total_workouts INTEGER,
  completed_workouts INTEGER,
  total_weight DECIMAL,
  completion_rate INTEGER
) AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get the current user's ID
  v_user_id := auth.uid();
  
  -- Verify partnership exists and is accepted
  IF NOT EXISTS (
    SELECT 1 FROM workout_partners
    WHERE status = 'accepted'
    AND (
      (user_id = v_user_id AND partner_id = $1) OR
      (partner_id = v_user_id AND user_id = $1)
    )
  ) AND v_user_id != $1 THEN
    RAISE EXCEPTION 'Not authorized to view partner stats';
  END IF;

  RETURN QUERY
  WITH workout_stats AS (
    SELECT 
      d.id as workout_id,
      d.completed as is_completed,
      COALESCE(SUM(CASE WHEN es.completed AND es.weight > 0 AND es.reps > 0 THEN es.weight ELSE 0 END), 0) as workout_weight
    FROM daily_workouts d
    LEFT JOIN workout_exercises we ON we.daily_workout_id = d.id
    LEFT JOIN exercise_sets es ON es.exercise_id = we.id
    WHERE d.user_id = $1
    AND d.date >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY d.id, d.completed
  )
  SELECT 
    COUNT(workout_id)::INTEGER as total_workouts,
    COUNT(CASE WHEN is_completed THEN 1 END)::INTEGER as completed_workouts,
    COALESCE(SUM(workout_weight), 0) as total_weight,
    CASE 
      WHEN COUNT(workout_id) > 0 THEN 
        (COUNT(CASE WHEN is_completed THEN 1 END) * 100 / COUNT(workout_id))::INTEGER
      ELSE 0 
    END as completion_rate
  FROM workout_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_partner_stats(UUID) TO authenticated;

-- Update RLS policies for better partner access
CREATE OR REPLACE POLICY "Enable read access for partners" ON daily_workouts
  FOR SELECT USING (
    auth.uid()::uuid = user_id OR
    EXISTS (
      SELECT 1 FROM workout_partners wp
      WHERE wp.status = 'accepted'
      AND (
        (wp.user_id = auth.uid()::uuid AND wp.partner_id = user_id) OR
        (wp.partner_id = auth.uid()::uuid AND wp.user_id = user_id)
      )
    )
  );