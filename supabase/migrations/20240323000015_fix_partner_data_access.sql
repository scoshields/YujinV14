-- Drop existing function and policies
DROP FUNCTION IF EXISTS get_partner_stats(UUID);
DROP POLICY IF EXISTS "Enable read access for partners" ON daily_workouts;

-- Create improved partner stats function
CREATE OR REPLACE FUNCTION get_partner_stats(partner_id UUID)
RETURNS TABLE (
  total_workouts INTEGER,
  completed_workouts INTEGER,
  total_weight DECIMAL,
  completion_rate INTEGER
) AS $$
BEGIN
  -- Simple direct query without partnership check
  RETURN QUERY
  SELECT 
    COUNT(DISTINCT d.id)::INTEGER as total_workouts,
    COUNT(DISTINCT CASE WHEN d.completed THEN d.id END)::INTEGER as completed_workouts,
    COALESCE(SUM(CASE WHEN es.completed AND es.weight > 0 AND es.reps > 0 THEN es.weight ELSE 0 END), 0) as total_weight,
    CASE 
      WHEN COUNT(DISTINCT d.id) > 0 THEN 
        (COUNT(DISTINCT CASE WHEN d.completed THEN d.id END) * 100 / COUNT(DISTINCT d.id))::INTEGER
      ELSE 0 
    END as completion_rate
  FROM daily_workouts d
  LEFT JOIN workout_exercises we ON we.daily_workout_id = d.id
  LEFT JOIN exercise_sets es ON es.exercise_id = we.id
  WHERE d.user_id = partner_id
  AND d.date >= CURRENT_DATE - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_partner_stats(UUID) TO authenticated;

-- Create simplified read policy for daily_workouts
CREATE POLICY "Enable read access for partners" ON daily_workouts
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